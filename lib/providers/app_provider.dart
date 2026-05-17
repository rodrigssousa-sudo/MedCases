import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js_interop;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drug_model.dart';
import '../models/protocol_model.dart';
import '../models/clinical_case_model.dart';
import '../models/clinical_history_model.dart';
import '../models/user_model.dart';
import '../data/drugs_database.dart';
import '../data/protocols_database.dart';
import '../data/cases_database.dart';
import '../services/firestore_service.dart';
import '../services/drug_interaction_service.dart';
import '../services/ai_service.dart';
import '../services/gemini_service.dart';

class DoseInfo {
  final String main;
  final String detail;
  final List<String> alerts;
  DoseInfo({required this.main, required this.detail, required this.alerts});
}

class PatientData {
  String patientId;
  String age;
  String sex;
  String weight;
  String height;
  String creatinine;
  String medications; // medicamentos em uso atual
  PatientData({
    this.patientId = '',
    this.age = '',
    this.sex = 'M',
    this.weight = '',
    this.height = '',
    this.creatinine = '',
    this.medications = '',
  });
}

class HemoData {
  String sbp, dbp, na, cl, hco3, glucose;
  HemoData({
    this.sbp = '120', this.dbp = '80',
    this.na = '140', this.cl = '104',
    this.hco3 = '24', this.glucose = '100',
  });
}

class AppProvider extends ChangeNotifier {
  // ── Estado Firebase ───────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _firebaseReady = false;

  // ── Estado local ──────────────────────────────────────────────────────────
  String _lang = 'es';
  bool _darkMode = false;

  PatientData _patient = PatientData();
  HemoData _hemo = HemoData();

  List<String> _selectedDrugIds = [];
  String _activeDrugId = '';

  List<ClinicalCaseModel> _customCases = [];
  Set<String> _favDrugs = {};
  Set<String> _favProtocols = {};
  Set<String> _favPrescriptions = {};
  Set<String> _favCases = {};

  // ── Estado — Histórias Clínicas ───────────────────────────────────────────
  List<ClinicalHistoryModel> _myHistories = [];
  List<ClinicalHistoryModel> _publicHistories = [];
  bool _isLoadingPublic = false;
  String _publicLoadError = '';

  String get publicLoadError => _publicLoadError;

  // ── Rastreamento de uso ────────────────────────────────────────────────────
  Timer? _usageTimer;
  int _sessionSeconds = 0;    // segundos acumulados nesta sessão (flush a cada 60s)
  bool _usagePaused = false;  // true quando app está em background

  // ── Estado — IA Clínica ──────────────────────────────────────────────────
  String _openAiKey = '';
  bool _aiKeyLoading = false; // true enquanto busca chave no Firestore
  // Histórico de conversa para contexto multi-turn (máx 10 pares)
  final List<Map<String, String>> _aiHistory = [];

  // ── Estado — Gemini OAuth (paralelo ao OpenAI, nunca interfere) ───────────
  bool _geminiConnected = false;   // true quando conta Google autorizada
  bool _geminiLoading   = false;   // true durante signIn/signOut
  String _geminiEmail   = '';      // e-mail exibido na UI

  // ── Getters públicos ──────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get firebaseReady => _firebaseReady;
  bool get loggedIn => _currentUser != null && _currentUser!.isApproved;
  bool get isPending => _currentUser != null && _currentUser!.isPending;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSupervisor => _currentUser?.isSupervisor ?? false;
  bool get isMaster => _currentUser?.isMaster ?? false;
  bool get canModerateContent => (_currentUser?.isAdmin ?? false) || (_currentUser?.isSupervisor ?? false);
  String get userName => _currentUser?.displayName ?? '';
  String get userEmail => _currentUser?.email ?? '';
  String get lang => _lang;
  bool get darkMode => _darkMode;
  PatientData get patient => _patient;
  HemoData get hemo => _hemo;
  String get activeDrugId => _activeDrugId;
  List<String> get selectedDrugIds => _selectedDrugIds;
  Set<String> get favDrugs => _favDrugs;
  Set<String> get favProtocols => _favProtocols;
  Set<String> get favPrescriptions => _favPrescriptions;
  Set<String> get favCases => _favCases;
  List<ClinicalCaseModel> get customCases => _customCases;

  // ── Getters — Histórias Clínicas ─────────────────────────────────────────
  List<ClinicalHistoryModel> get myHistories => _myHistories;
  List<ClinicalHistoryModel> get publicHistories => _publicHistories;
  bool get isLoadingPublic => _isLoadingPublic;

  // ── Getters — IA ─────────────────────────────────────────────────────────
  String get openAiKey => _openAiKey;
  bool get hasAiKey => _openAiKey.isNotEmpty;
  bool get aiKeyLoading => _aiKeyLoading;

  // ── Getters — Gemini OAuth ────────────────────────────────────────────────
  bool get geminiConnected => _geminiConnected;
  bool get geminiLoading   => _geminiLoading;
  String get geminiEmail   => _geminiEmail;
  /// true quando qualquer IA real está disponível (OpenAI OU Gemini)
  bool get hasAnyAi => _openAiKey.isNotEmpty || _geminiConnected;

  // Deduplica por ID (garante que entradas duplicadas na database não apareçam duas vezes)
  List<DrugModel> get drugsDB {
    final seen = <String>{};
    return drugsDatabase.where((d) => seen.add(d.id)).toList();
  }
  List<ProtocolModel> get protocolsDB => protocolsDatabase;
  List<ClinicalCaseModel> get casesDB => casesDatabase;

  DrugModel? get activeDrug {
    if (_activeDrugId.isEmpty) return null;
    try {
      return drugsDatabase.firstWhere((d) => d.id == _activeDrugId);
    } catch (_) {
      return null; // id obsoleto — não retorna drug errado
    }
  }

  List<DrugModel> get selectedDrugs {
    final result = <DrugModel>[];
    for (final id in _selectedDrugIds) {
      try {
        result.add(drugsDatabase.firstWhere((d) => d.id == id));
      } catch (_) {
        // id não encontrado no banco — ignora silenciosamente
        // (evita retornar drug errado ou crash com RangeError)
      }
    }
    return result;
  }

  // ── Login com usuário do Firebase ─────────────────────────────────────────
  Future<void> setUser(UserModel user) async {
    _currentUser = user;
    _lang = user.lang;
    _darkMode = user.darkMode;
    _firebaseReady = true;

    // 1️⃣ Carrega cache local IMEDIATAMENTE — app responde sem esperar rede
    await _loadFromLocal(uid: user.uid);

    // 2️⃣ Carrega chaves do Firestore com AWAIT — SEMPRE executa (nunca condicional).
    //    openAiKey: garante hasAiKey=true antes da UI montar.
    //    geminiApiKey: CRÍTICO — não tem cache local, deve ser sempre buscada.
    //    Timeout 5s para não travar login em redes lentas; falha silenciosa = modo local.
    await _loadAiKeyFromFirestore(user.uid).timeout(
      const Duration(seconds: 5),
      onTimeout: () { _aiKeyLoading = false; },
    );

    // 3️⃣ Sincroniza Firestore em background — não bloqueia a UI
    _syncFromFirestore(user.uid);

    // 4️⃣ Carrega histórias públicas AQUI — token já está cacheado neste ponto.
    loadPublicHistories();

    // 5️⃣ Restaura sessão Gemini em background — silencioso, não bloqueia UI
    Future.delayed(
      _webGetLS('medcases_gsi_pending') == 'true'
          ? const Duration(seconds: 1)
          : Duration.zero,
      checkGeminiSession,
    );

    // 6️⃣ Inicia contador de tempo de uso
    _startUsageTimer(user.uid);
  }

  // ── Timer de uso ──────────────────────────────────────────────────────────
  // Conta tempo de tela REAL: inicia ao abrir o app, pausa no background,
  // retoma ao trazer o app de volta. Grava no Firestore a cada 60s.
  // Não depende de cliques, pesquisas ou digitação — mede presença na tela.
  void _startUsageTimer(String uid) {
    _usageTimer?.cancel();
    _sessionSeconds = 0;
    _usagePaused = false;
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_usagePaused) return; // app em background — não conta
      _sessionSeconds++;
      // Flush a cada 60 segundos → 1 escrita no Firestore por minuto de uso
      if (_sessionSeconds % 60 == 0) {
        FirestoreService.incrementUsage(uid, 60);
      }
    });
  }

  /// Pausa o timer quando o app vai para background (não cancela — mantém estado).
  /// Chamado pelo MainShell via didChangeAppLifecycleState(paused/hidden/inactive).
  void pauseUsageTimer() {
    if (_usageTimer == null || _usagePaused) return;
    _usagePaused = true;
    // Flush imediato dos segundos acumulados antes de pausar
    final uid = _currentUser?.uid;
    if (uid != null) {
      final residual = _sessionSeconds % 60;
      if (residual > 0) FirestoreService.incrementUsage(uid, residual);
      _sessionSeconds = (_sessionSeconds ~/ 60) * 60; // zera o residual
    }
    debugPrint('[UsageTimer] pausado — app em background');
  }

  /// Retoma o timer quando o app volta ao foreground.
  /// Chamado pelo MainShell via didChangeAppLifecycleState(resumed).
  void resumeUsageTimer() {
    if (_usageTimer == null) {
      // Timer não existe ainda — pode ter sido cancelado; reinicia
      final uid = _currentUser?.uid;
      if (uid != null) _startUsageTimer(uid);
      return;
    }
    if (!_usagePaused) return;
    _usagePaused = false;
    debugPrint('[UsageTimer] retomado — app em foreground');
  }

  void _stopUsageTimer() {
    final uid = _currentUser?.uid;
    if (uid != null && _sessionSeconds > 0) {
      // Grava os segundos residuais que ainda não foram enviados
      final residual = _sessionSeconds % 60;
      if (residual > 0) FirestoreService.incrementUsage(uid, residual);
    }
    _usageTimer?.cancel();
    _usageTimer = null;
    _sessionSeconds = 0;
    _usagePaused = false;
  }

  void clearUser() {
    _stopUsageTimer();
    _currentUser = null;
    _firebaseReady = false;
    _favDrugs = {};
    _favProtocols = {};
    _favPrescriptions = {};
    _favCases = {};
    _customCases = [];
    _myHistories = [];
    _publicHistories = [];
    _selectedDrugIds = [];
    _activeDrugId = '';
    _patient = PatientData();
    _hemo = HemoData();
    // Limpa chave, histórico de IA e estado Gemini ao fazer logout
    _openAiKey = '';
    _aiHistory.clear();
    _geminiConnected = false;
    _geminiEmail = '';
    notifyListeners();
  }

  void setFirebaseReady() {
    _firebaseReady = true;
    notifyListeners();
  }

  // ── Chave OpenAI — prioridade: app global → usuário individual → cache local
  //
  // Hierarquia:
  //  1. app_config/global.openAiKey  → chave do app (admin configura, todos usam)
  //  2. users/{uid}/prefs/settings.openAiKey → chave individual (legado / admin)
  //  3. SharedPreferences local → fallback offline
  Future<void> _loadAiKeyFromFirestore(String uid) async {
    try {
      // Carrega OpenAI Key e Gemini API Key em paralelo — mais rápido
      // CRÍTICO: geminiApiKey NUNCA tem return prematuro — deve sempre ser carregada
      final results = await Future.wait([
        FirestoreService.loadAppAiKey(),
        FirestoreService.loadGeminiApiKey(),
      ]);

      final appKey    = results[0];
      final geminiKey = results[1];

      // ── OpenAI Key ──────────────────────────────────────────────────────────
      if (appKey.isNotEmpty) {
        _openAiKey = appKey;
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', uid), appKey);
      } else {
        // Fallback: chave individual do usuário (legado)
        final userKey = await FirestoreService.loadAiKey(uid);
        if (userKey.isNotEmpty) {
          _openAiKey = userKey;
          final p = await SharedPreferences.getInstance();
          await p.setString(_k('openAiKey', uid), userKey);
        }
      }

      // ── Gemini API Key — injeta no GeminiService + cacheia localmente ──────
      if (geminiKey.isNotEmpty) {
        GeminiService.setGeminiApiKey(geminiKey); // persiste em SharedPrefs + mcLsSet
        debugPrint('[AppProvider] Gemini API Key carregada e cacheada ✓');
      } else {
        // Firestore retornou vazio — tenta SharedPreferences (primário, sem dart:js)
        if (!GeminiService.hasApiKey) {
          await GeminiService.initFromStorage();
        }
        if (GeminiService.hasApiKey) {
          debugPrint('[AppProvider] Gemini API Key restaurada do SharedPrefs/cache ✓');
        } else {
          debugPrint('[AppProvider] Gemini API Key não encontrada em nenhuma fonte');
        }
      }

      _aiKeyLoading = false;
      notifyListeners();
    } catch (_) {
      // Sem rede: tenta cache local para OpenAI
      try {
        final p = await SharedPreferences.getInstance();
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
      } catch (_) {}
      // Restaura Gemini Key do SharedPrefs/localStorage se Firestore falhou
      if (!GeminiService.hasApiKey) {
        await GeminiService.initFromStorage();
        if (GeminiService.hasApiKey) {
          debugPrint('[AppProvider] Gemini Key restaurada do SharedPrefs (rede falhou) ✓');
        }
      }
      _aiKeyLoading = false;
      notifyListeners();
    }
  }

  // ── Sincronização background com Firestore ────────────────────────────────
  // Chamado APÓS _loadFromLocal — atualiza silenciosamente quando há rede
  Future<void> _syncFromFirestore(String uid) async {
    try {
      final results = await Future.wait([
        FirestoreService.loadFavDrugs(uid),
        FirestoreService.loadFavProtocols(uid),
        FirestoreService.loadFavPrescriptions(uid),
        FirestoreService.loadFavCases(uid),
      ]);
      _favDrugs         = results[0];
      _favProtocols     = results[1];
      _favPrescriptions = results[2];
      _favCases         = results[3];
      _customCases      = await FirestoreService.loadCases(uid);
      notifyListeners();
      // Persiste no cache local para próxima abertura offline
      await _saveLocal();
      // Histórias clínicas em paralelo (não bloqueia)
      _syncHistoriesFromFirestore(uid);
    } catch (_) {
      // Sem rede: mantém dados do cache — nenhuma ação necessária
    }
  }

  Future<void> _syncHistoriesFromFirestore(String uid) async {
    try {
      final histories = await FirestoreService.loadHistories(uid);
      _myHistories = histories;
      notifyListeners();
      // Persiste histórias no cache local
      await _saveHistoriesLocal(uid);
    } catch (_) {}
  }

  // ── Cache local (SharedPreferences) ──────────────────────────────────────
  // Prefixo por uid garante que usuários diferentes não compartilhem cache
  String _k(String key, String? uid) => uid != null ? '${uid}_$key' : key;

  Future<void> loadPrefs() async {
    await _loadFromLocal();
  }

  Future<void> _loadFromLocal({String? uid}) async {
    try {
      final p = await SharedPreferences.getInstance();

      // Preferências globais (independentes de usuário)
      _lang     = p.getString('lang')     ?? 'es';
      _darkMode = p.getBool('darkMode')   ?? false;
      // Chave de IA — lida com prefixo de usuário se disponível (fallback offline)
      if (uid != null) {
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
      }

      // Dados por usuário (se uid disponível usa cache dedicado)
      final favKey   = _k('favDrugs',         uid);
      final protKey  = _k('favProtocols',     uid);
      final prescKey = _k('favPrescriptions', uid);
      final caseKey  = _k('customCases',      uid);
      final favCaseKey = _k('favCases',       uid);
      final histKey  = _k('myHistories',      uid);

      _favDrugs         = (p.getStringList(favKey)   ?? p.getStringList('favDrugs')         ?? []).toSet();
      _favProtocols     = (p.getStringList(protKey)  ?? p.getStringList('favProtocols')     ?? []).toSet();
      _favPrescriptions = (p.getStringList(prescKey) ?? p.getStringList('favPrescriptions') ?? []).toSet();
      _favCases         = (p.getStringList(favCaseKey) ?? p.getStringList('favCases')       ?? []).toSet();

      final casesJson = p.getString(caseKey) ?? p.getString('customCases');
      if (casesJson != null) {
        try {
          final list = jsonDecode(casesJson) as List;
          _customCases = list
              .map((e) => ClinicalCaseModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      // Histórias clínicas em cache
      final histJson = p.getString(histKey);
      if (histJson != null) {
        try {
          final list = jsonDecode(histJson) as List;
          _myHistories = list
              .map((e) => ClinicalHistoryModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveLocal({String? uid}) async {
    final u = uid ?? _currentUser?.uid;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang',     _lang);
      await p.setBool('darkMode',   _darkMode);
      // Chave de IA só persiste com prefixo de usuário (nunca global)
      if (u != null && _openAiKey.isNotEmpty) {
        await p.setString(_k('openAiKey', u), _openAiKey);
      }
      await p.setStringList(_k('favDrugs',         u), _favDrugs.toList());
      await p.setStringList(_k('favProtocols',     u), _favProtocols.toList());
      await p.setStringList(_k('favPrescriptions', u), _favPrescriptions.toList());
      await p.setStringList(_k('favCases',         u), _favCases.toList());
      await p.setString(_k('customCases', u),
          jsonEncode(_customCases.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  // Salva apenas as histórias no cache (chamado após sync ou write)
  Future<void> _saveHistoriesLocal(String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k('myHistories', uid),
          jsonEncode(_myHistories.map((h) => h.toJson()).toList()));
    } catch (_) {}
  }

  // ── i18n helpers ──────────────────────────────────────────────────────────
  String tDB(Map<String, String>? field) {
    if (field == null) return '';
    return field[_lang] ?? field['es'] ?? field['pt'] ?? '';
  }

  String t(String key) {
    return _translations[_lang]?[key] ?? _translations['es']?[key] ?? key;
  }

  // ── Cálculos clínicos ─────────────────────────────────────────────────────
  double? _parseNum(String val) {
    final v = double.tryParse(val.replaceAll(',', '.'));
    return (v != null && v.isFinite) ? v : null;
  }

  String _fmt(double v) {
    if (!v.isFinite) return '—';
    if (v.abs() >= 100) return v.round().toString();
    return ((v * 10).round() / 10).toString().replaceAll('.', ',');
  }

  String? get bmi {
    final w = _parseNum(_patient.weight);
    final h = _parseNum(_patient.height);
    if (w == null || h == null || h == 0) return null;
    final hm = h / 100;
    return _fmt(w / (hm * hm));
  }

  String? get clcr {
    final cr = _parseNum(_patient.creatinine);
    final a = _parseNum(_patient.age);
    final w = _parseNum(_patient.weight);
    if (cr == null || a == null || w == null || cr == 0) return null;
    double v = (140 - a) * w / (72 * cr);
    if (_patient.sex == 'Feminino' || _patient.sex == 'Femenino') v *= 0.85;
    return _fmt(v);
  }

  String? get map {
    final s = _parseNum(_hemo.sbp);
    final d = _parseNum(_hemo.dbp);
    if (s == null || d == null) return null;
    return _fmt((s + 2 * d) / 3);
  }

  String? get anionGap {
    final n = _parseNum(_hemo.na);
    final c = _parseNum(_hemo.cl);
    final b = _parseNum(_hemo.hco3);
    if (n == null || c == null || b == null) return null;
    return _fmt(n - (c + b));
  }

  String? get correctedNa {
    final n = _parseNum(_hemo.na);
    final g = _parseNum(_hemo.glucose);
    if (n == null || g == null) return null;
    return _fmt(n + 1.6 * ((g - 100) / 100));
  }

  DoseInfo calculateDose(DrugModel drug) {
    final w = _parseNum(_patient.weight);
    final a = _parseNum(_patient.age);
    final clcrVal = _parseNum(clcr ?? '');
    final alerts = <String>[];

    if ((drug.doseType == 'weight' || drug.doseType == 'infusion') && w == null) {
      alerts.add(_lang == 'es'
          ? 'Peso obligatorio para cálculo por kg o infusión.'
          : 'Peso obrigatório para cálculo por kg ou infusão.');
    }

    final renalAlert = drug.getField(drug.renalAlert, _lang);
    if (clcrVal != null && clcrVal > 0 && clcrVal < 50 && renalAlert.isNotEmpty &&
        !renalAlert.toLowerCase().contains('sem ajuste') &&
        !renalAlert.toLowerCase().contains('sin ajuste')) {
      alerts.add('Ajuste renal: ClCr ${clcr ?? '—'} mL/min. $renalAlert');
    }

    final elderlyAlert = drug.getField(drug.elderlyAlert, _lang);
    if (a != null && a >= 65 && elderlyAlert.isNotEmpty) {
      alerts.add('${_lang == 'es' ? 'Paciente anciano: ' : 'Paciente idoso: '}$elderlyAlert');
    }

    if (drug.doseType == 'weight' && w != null && drug.mgKg != null) {
      return DoseInfo(
        main: '${_fmt(w * drug.mgKg!)} mg/dose',
        detail: '${drug.mgKg} mg/kg. ${drug.getField(drug.frequency, _lang)}',
        alerts: alerts,
      );
    }

    if (drug.doseType == 'infusion' && w != null && drug.mcgKgMinStart != null && drug.mcgKgMinMax != null) {
      return DoseInfo(
        main: '${_fmt(w * drug.mcgKgMinStart!)}–${_fmt(w * drug.mcgKgMinMax!)} mcg/min',
        detail: '${drug.mcgKgMinStart}–${drug.mcgKgMinMax} mcg/kg/min em bomba. Titular por resposta clínica.',
        alerts: alerts,
      );
    }

    final fixedDose = drug.getField(drug.fixedDose, _lang);
    return DoseInfo(
      main: fixedDose.isNotEmpty ? fixedDose : (_lang == 'es' ? 'Dosis según protocolo local' : 'Dose conforme protocolo local'),
      detail: _lang == 'es'
          ? 'Individualizar por indicación, función renal/hepática, alergias y presentación disponible.'
          : 'Individualizar por indicação, função renal/hepática, alergias e apresentação disponível.',
      alerts: alerts,
    );
  }

  /// Interações detectadas via DrugInteractionService (fármacos selecionados + medicamentos do paciente)
  List<DrugInteraction> get drugInteractions {
    if (_selectedDrugIds.isEmpty) return [];
    final selectedNames = selectedDrugs.map((d) => d.name).toList();
    return DrugInteractionService.checkInteractions(
      selectedDrugNames: selectedNames,
      patientMedicationsText: _patient.medications,
    );
  }

  /// Compatibilidade legada — retorna strings simples para widgets antigos
  List<String> get interactionRisks =>
      drugInteractions.map((i) => '${i.drug1} + ${i.drug2}: ${i.effect}').toList();

  // ── Mutations de estado ───────────────────────────────────────────────────
  /// Atualiza nome, profissão e instituição do usuário logado
  Future<void> updateProfile({String? displayName, String? profession, String? institution}) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      profession: profession,
      institution: institution,
    );
    notifyListeners();
    await FirestoreService.updateUserProfile(
      _currentUser!.uid,
      displayName: displayName,
      profession: profession,
      institution: institution,
    );
  }

  void setLang(String l) {
    _lang = l;
    _saveLocal();
    if (_currentUser != null) {
      FirestoreService.updateUserProfile(_currentUser!.uid, lang: l);
    }
    notifyListeners();
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    _saveLocal();
    if (_currentUser != null) {
      FirestoreService.updateUserProfile(_currentUser!.uid, darkMode: _darkMode);
    }
    notifyListeners();
  }

  void updatePatient(String key, String value) {
    switch (key) {
      case 'patientId':    _patient.patientId = value; break;
      case 'age':           _patient.age = value; break;
      case 'sex':           _patient.sex = value; break;
      case 'weight':        _patient.weight = value; break;
      case 'height':        _patient.height = value; break;
      case 'creatinine':    _patient.creatinine = value; break;
      case 'medications':   _patient.medications = value; break;
    }
    notifyListeners();
  }

  void resetPatient() {
    _patient = PatientData();
    _selectedDrugIds = [];
    _activeDrugId = '';
    notifyListeners();
  }

  void updateHemo(String key, String value) {
    switch (key) {
      case 'sbp':     _hemo.sbp = value; break;
      case 'dbp':     _hemo.dbp = value; break;
      case 'na':      _hemo.na = value; break;
      case 'cl':      _hemo.cl = value; break;
      case 'hco3':    _hemo.hco3 = value; break;
      case 'glucose': _hemo.glucose = value; break;
    }
    notifyListeners();
  }

  void setActiveDrug(String id) {
    _activeDrugId = id;
    if (!_selectedDrugIds.contains(id)) _selectedDrugIds.add(id);
    notifyListeners();
  }

  void addDrug(String id) {
    if (!_selectedDrugIds.contains(id)) {
      _selectedDrugIds.add(id);
      _activeDrugId = id;
    }
    notifyListeners();
  }

  void removeDrug(String id) {
    _selectedDrugIds.remove(id);
    if (_selectedDrugIds.isEmpty) {
      _activeDrugId = '';
    } else if (_activeDrugId == id) {
      _activeDrugId = _selectedDrugIds.first;
    }
    notifyListeners();
  }

  void toggleFavDrug(String id) {
    if (_favDrugs.contains(id)) _favDrugs.remove(id); else _favDrugs.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavDrugs(_currentUser!.uid, _favDrugs);
    notifyListeners();
  }

  void toggleFavProtocol(String id) {
    if (_favProtocols.contains(id)) _favProtocols.remove(id); else _favProtocols.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavProtocols(_currentUser!.uid, _favProtocols);
    notifyListeners();
  }

  void toggleFavPrescription(String id) {
    if (_favPrescriptions.contains(id)) _favPrescriptions.remove(id); else _favPrescriptions.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavPrescriptions(_currentUser!.uid, _favPrescriptions);
    notifyListeners();
  }

  void toggleFavCase(String id) {
    if (_favCases.contains(id)) _favCases.remove(id); else _favCases.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavCases(_currentUser!.uid, _favCases);
    notifyListeners();
  }

  // ── Recentes — chave prefixada por uid para sobreviver a logout/login ─────
  static const _kRecentBase = 'home_recents_v1';

  String _recentKey(String? uid) =>
      uid != null ? '${uid}_$_kRecentBase' : _kRecentBase;

  /// Registra um item como recente (type|id|title), com chave por uid.
  Future<void> registerRecent(String type, String id, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _recentKey(_currentUser?.uid);
      final raw   = prefs.getStringList(key) ?? [];
      final entry = '$type|$id|$title';
      raw.removeWhere((e) => e.startsWith('$type|$id|'));
      raw.insert(0, entry);
      await prefs.setStringList(key, raw.take(20).toList());
    } catch (_) {}
  }

  /// Lê a lista de recentes do usuário atual.
  Future<List<Map<String, String>>> loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _recentKey(_currentUser?.uid);
      final raw   = prefs.getStringList(key) ?? [];
      return raw.map((e) {
        final parts = e.split('|');
        if (parts.length < 3) return null;
        return {'type': parts[0], 'id': parts[1], 'title': parts.sublist(2).join('|')};
      }).whereType<Map<String, String>>().toList();
    } catch (_) {
      return [];
    }
  }

  void saveCase(ClinicalCaseModel c) {
    final idx = _customCases.indexWhere((x) => x.id == c.id);
    if (idx >= 0) _customCases[idx] = c; else _customCases.insert(0, c);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveCase(_currentUser!.uid, c);
    notifyListeners();
  }

  void deleteCase(String id) {
    _customCases.removeWhere((c) => c.id == id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.deleteCase(_currentUser!.uid, id);
    notifyListeners();
  }

  // ── Histórias Clínicas ────────────────────────────────────────────────────
  Future<void> loadHistories() async {
    if (_currentUser == null) return;
    try {
      _myHistories = await FirestoreService.loadHistories(_currentUser!.uid);
      notifyListeners();
      // Persiste no cache para uso offline
      await _saveHistoriesLocal(_currentUser!.uid);
    } catch (_) {
      // Sem rede: histórias já carregadas do cache em _loadFromLocal()
    }
  }

  Future<void> saveHistory(ClinicalHistoryModel h) async {
    if (_currentUser == null) return;

    // ── 1. Atualiza _myHistories na memória ──────────────────────────────────
    final idx = _myHistories.indexWhere((x) => x.id == h.id);
    if (idx >= 0) {
      _myHistories[idx] = h;
    } else {
      _myHistories.insert(0, h);
    }

    // ── 2. Atualiza _publicHistories na memória imediatamente ────────────────
    // Faz isso ANTES do Firestore para que o criador veja a própria HC
    // na aba Comunidade sem precisar recarregar.
    if (h.isPublic) {
      final pubIdx = _publicHistories.indexWhere((x) => x.id == h.id);
      // Garante uploadedAt não-vazio para a exibição local
      final uploadedAt = h.uploadedAt.isNotEmpty
          ? h.uploadedAt
          : DateTime.now().toIso8601String();
      final publicVersion = h.copyWith(uploadedAt: uploadedAt, isHidden: false);
      if (pubIdx >= 0) {
        _publicHistories[pubIdx] = publicVersion;
      } else {
        _publicHistories.insert(0, publicVersion);
      }
      // Re-ordena para manter consistência
      _publicHistories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      // Removeu o isPublic: tira da lista pública local imediatamente
      _publicHistories.removeWhere((x) => x.id == h.id);
    }

    // ── 3. Persiste no cache local e notifica UI ─────────────────────────────
    await _saveHistoriesLocal(_currentUser!.uid);
    notifyListeners();

    // ── 4. Sincroniza com Firestore em background ────────────────────────────
    // Agora awaita + propaga o uploadedAt real de volta ao modelo local
    FirestoreService.saveHistory(_currentUser!.uid, h).then((uploadedAt) {
      if (uploadedAt != null && uploadedAt.isNotEmpty && h.isPublic) {
        // Atualiza uploadedAt no modelo local com o valor confirmado pelo servidor
        final pubIdx = _publicHistories.indexWhere((x) => x.id == h.id);
        if (pubIdx >= 0 && _publicHistories[pubIdx].uploadedAt != uploadedAt) {
          _publicHistories[pubIdx] = _publicHistories[pubIdx].copyWith(uploadedAt: uploadedAt);
          // Também sincroniza em _myHistories
          final myIdx = _myHistories.indexWhere((x) => x.id == h.id);
          if (myIdx >= 0) {
            _myHistories[myIdx] = _myHistories[myIdx].copyWith(uploadedAt: uploadedAt);
          }
          _saveHistoriesLocal(_currentUser!.uid).catchError((_) {});
          notifyListeners();
        }
      }
    }).catchError((_) {
      // Falha no Firestore: dados já estão na memória/cache local.
      // Na próxima conexão, loadHistories() sincroniza automaticamente.
    });
  }

  Future<void> deleteHistory(String id, {bool wasPublic = false}) async {
    if (_currentUser == null) return;
    _myHistories.removeWhere((h) => h.id == id);
    // Remove da lista pública local também (independente de wasPublic)
    _publicHistories.removeWhere((h) => h.id == id);
    // Atualiza cache local imediatamente
    await _saveHistoriesLocal(_currentUser!.uid);
    notifyListeners();
    // Sincroniza deleção com Firestore em background
    FirestoreService.deleteHistory(_currentUser!.uid, id, wasPublic: wasPublic)
        .catchError((_) {});
  }

  Future<void> toggleHistoryPublic(ClinicalHistoryModel h) async {
    final updated = h.copyWith(isPublic: !h.isPublic);
    await saveHistory(updated);
  }

  // Completer ativo enquanto um fetch está em andamento.
  // Chamadas concorrentes aguardam o mesmo Future em vez de retornar [] silenciosamente.
  Completer<void>? _publicHistoriesCompleter;

  Future<void> loadPublicHistories() async {
    // Já há um fetch em andamento — aguarda ele terminar (não cancela nem ignora)
    if (_publicHistoriesCompleter != null) {
      await _publicHistoriesCompleter!.future;
      return;
    }

    _publicHistoriesCompleter = Completer<void>();
    _isLoadingPublic = true;
    _publicLoadError = '';
    notifyListeners();
    try {
      final fetched = await FirestoreService.loadPublicHistories();
      // Mescla: preserva HCs locais do criador que ainda não chegaram ao servidor
      final mergedIds = <String>{};
      final merged = <ClinicalHistoryModel>[];
      for (final h in fetched) {
        merged.add(h);
        mergedIds.add(h.id);
      }
      for (final local in _publicHistories) {
        if (!mergedIds.contains(local.id) && local.isPublic) {
          merged.add(local);
        }
      }
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _publicHistories = merged;
    } catch (e, st) {
      _publicLoadError = '$e\n$st';
    } finally {
      _isLoadingPublic = false;
      _publicHistoriesCompleter!.complete();
      _publicHistoriesCompleter = null;
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void logout() {
    clearUser();
  }

  // ── IA Clínica ────────────────────────────────────────────────────────────

  /// Salva a chave OpenAI GLOBAL do app (admin → todos os usuários).
  /// Persiste em app_config/global.openAiKey + atualiza estado local.
  Future<void> setAppAiKey(String key) async {
    final trimmed = key.trim();
    _openAiKey = trimmed;
    notifyListeners();
    await FirestoreService.saveAppAiKey(trimmed);
    // Atualiza cache local do usuário atual também
    if (_currentUser != null) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', _currentUser!.uid), trimmed);
      } catch (_) {}
    }
  }

  /// Salva a chave OpenAI vinculada ao UID do usuário logado.
  /// Persiste no Firestore (sync entre dispositivos) + cache local (offline).
  Future<void> setAiKey(String key) async {
    if (_currentUser == null) return;
    _openAiKey = key.trim();
    notifyListeners();
    final uid = _currentUser!.uid;
    // Persiste no Firestore do usuário
    FirestoreService.saveAiKey(uid, _openAiKey).catchError((_) {});
    // Persiste no cache local com prefixo do usuário (funciona offline)
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k('openAiKey', uid), _openAiKey);
    } catch (_) {}
  }

  /// Limpa o histórico de conversa da IA (nova conversa)
  void clearAiHistory() => _aiHistory.clear();

  // ── Gemini OAuth — conectar / desconectar ─────────────────────────────────

  /// Inicia fluxo OAuth Google → abre seletor de conta nativo.
  ///
  /// Retorna:
  ///   true  → conectou com sucesso (Android ou web sem redirect)
  ///   false → falha real (cancelou, erro de rede, etc.)
  ///   null  → redirect OAuth iniciado no Safari/web (página vai recarregar;
  ///            o token chegará via checkGeminiSession() no próximo boot)
  Future<bool?> connectGemini() async {
    _geminiLoading = true;
    notifyListeners();
    try {
      // No web com redirect flow, signIn() retorna false imediatamente após
      // abrir o modal — a página vai recarregar. Precisamos distinguir isso
      // de uma falha real. A flag 'medcases_gsi_modal_opened' no JS sinaliza
      // que o modal foi aberto (redirect em andamento).
      final ok = await GeminiService.signIn()
          .timeout(const Duration(seconds: 30), onTimeout: () => false);

      if (ok) {
        _geminiConnected = true;
        _geminiEmail = await GeminiService.connectedEmail() ?? '';
        return true;
      }

      // Verifica se o modal foi aberto (redirect flow no web)
      if (kIsWeb) {
        try {
          final modalOpened = _webGetLS('medcases_gsi_modal_opened');
          if (modalOpened == 'true') {
            _webRemoveLS('medcases_gsi_modal_opened');
            debugPrint('[connectGemini] redirect OAuth iniciado — aguardando reload');
            return null; // null = redirect em andamento, não é falha
          }
        } catch (_) {}
      }

      return false;
    } catch (e, st) {
      debugPrint('[connectGemini] ERRO: $e');
      debugPrint('[connectGemini] STACK: $st');
      return false;
    } finally {
      _geminiLoading = false;
      notifyListeners();
    }
  }

  /// Desconecta a conta Google do Gemini.
  Future<void> disconnectGemini() async {
    _geminiLoading = true;
    notifyListeners();
    try {
      await GeminiService.signOut();
      _geminiConnected = false;
      _geminiEmail = '';
    } finally {
      _geminiLoading = false;
      notifyListeners();
    }
  }

  /// Verifica silenciosamente se há sessão Gemini ativa (chamado no login).
  /// Nunca propaga exceção nem modifica _geminiLoading — é 100% silencioso.
  ///
  /// Nova lógica (Session 4 — API Key auth):
  ///   Fluxo redirect OAuth (Safari/web):
  ///   1. JS em index.html salva email (via tokeninfo) + seta 'medcases_gsi_pending'
  ///   2. Este método detecta a flag, lê o email do localStorage
  ///   3. _geminiConnected = true se email salvo E Gemini API Key carregada
  Future<void> checkGeminiSession() async {
    try {
      if (kIsWeb) {
        // Limpa flag de modal órfã (pode sobrar de tentativas anteriores)
        _webRemoveLS('medcases_gsi_modal_opened');

        // ── Detecta retorno do redirect OAuth ───────────────────────────────
        final pending = _webGetLS('medcases_gsi_pending');
        if (pending == 'true') {
          _webRemoveLS('medcases_gsi_pending');

          // Com API Key arch: apenas o email é necessário (token não é usado)
          var email = _webGetLS('gemini_google_email') ?? '';
          if (email.isEmpty) {
            // Email ainda não chegou (fetch async do JS) — aguarda até 1s
            await Future.delayed(const Duration(milliseconds: 600));
            email = _webGetLS('gemini_google_email') ?? '';
          }
          if (email.isEmpty) {
            email = await GeminiService.connectedEmail() ?? '';
          }
          if (email.isNotEmpty) {
            // Email presente = usuário autenticou com sucesso.
            // Garante que a API Key está carregada (pode ter sido perdida por reload)
            if (!GeminiService.hasApiKey) {
              debugPrint('[checkGeminiSession] API Key ausente após redirect — tentando Firestore REST...');
              try {
                final geminiKey = await FirestoreService.loadGeminiApiKey()
                    .timeout(const Duration(seconds: 8));
                if (geminiKey.isNotEmpty) {
                  GeminiService.setGeminiApiKey(geminiKey); // persiste em SharedPrefs + mcLsSet
                  debugPrint('[checkGeminiSession] API Key recarregada do Firestore REST ✓');
                } else {
                  // Firestore vazio — SharedPreferences é o fallback primário (sem dart:js)
                  await GeminiService.initFromStorage();
                  if (GeminiService.hasApiKey) {
                    debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs (pós-redirect) ✓');
                  }
                }
              } catch (e) {
                debugPrint('[checkGeminiSession] Firestore REST falhou: $e — tentando SharedPrefs...');
                await GeminiService.initFromStorage();
                if (GeminiService.hasApiKey) {
                  debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs (pós-redirect fallback) ✓');
                }
              }
            }
            _geminiConnected = true;
            _geminiEmail = email;
            debugPrint('[checkGeminiSession] redirect OAuth OK — $email, apiKey: ${GeminiService.hasApiKey}');
            notifyListeners();
            return;
          }
        }
      }

      // ── Verificação normal de sessão existente (não-redirect) ──────────
      // Garante API Key carregada antes de verificar isConnected()
      if (!GeminiService.hasApiKey) {
        debugPrint('[checkGeminiSession] API Key ausente — tentando Firestore...');
        try {
          final geminiKey = await FirestoreService.loadGeminiApiKey()
              .timeout(const Duration(seconds: 5));
          if (geminiKey.isNotEmpty) {
            GeminiService.setGeminiApiKey(geminiKey); // persiste em SharedPrefs + mcLsSet
            debugPrint('[checkGeminiSession] API Key recarregada do Firestore ✓');
          } else {
            // Firestore vazio — SharedPreferences é o fallback primário (sem dart:js/eval)
            await GeminiService.initFromStorage();
            if (GeminiService.hasApiKey) {
              debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs ✓');
            }
          }
        } catch (e) {
          debugPrint('[checkGeminiSession] Firestore falhou: $e — tentando SharedPrefs...');
          await GeminiService.initFromStorage();
          if (GeminiService.hasApiKey) {
            debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs (fallback) ✓');
          }
        }
      }
      final connected = await GeminiService.isConnected()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (connected) {
        _geminiConnected = true;
        _geminiEmail = await GeminiService.connectedEmail() ?? '';
        debugPrint('[checkGeminiSession] sessão existente — $_geminiEmail, apiKey: ${GeminiService.hasApiKey}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[checkGeminiSession] erro: $e');
      _geminiConnected = false;
      _geminiEmail = '';
    }
  }


  /// Lê um valor do localStorage via função global window.mcLsGet.
  /// A função é registrada no index.html ANTES do Firebase/SES lockdown ser
  /// aplicado — captura a referência nativa ao localStorage enquanto ainda
  /// é acessível. Sem eval, sem proxies congelados: compatível com qualquer CSP.
  String? _webGetLS(String key) {
    if (!kIsWeb) return null;
    try {
      final result = js_interop.context.callMethod('mcLsGet', [key]);
      if (result == null || result.toString() == 'null') return null;
      return result.toString();
    } catch (_) {
      return null;
    }
  }

  /// Grava um valor no localStorage via função global window.mcLsSet.
  /// Sem eval — compatível com CSP strict e SES lockdown do Firebase Auth.
  // ignore: unused_element
  void _webSetLS(String key, String value) {
    if (!kIsWeb) return;
    try {
      js_interop.context.callMethod('mcLsSet', [key, value]);
    } catch (_) {}
  }

  /// Remove uma chave do localStorage via função global window.mcLsRemove.
  /// Sem eval — compatível com CSP strict e SES lockdown do Firebase Auth.
  void _webRemoveLS(String key) {
    if (!kIsWeb) return;
    try {
      js_interop.context.callMethod('mcLsRemove', [key]);
    } catch (_) {}
  }

  /// Retorna sumários dos protocolos cujos títulos/reconhecer contenham keywords da query
  List<String> _matchProtocols(String normalizedQuery) {
    // Protocolos de alta emergência exigem ≥2 palavras da query para match,
    // evitando falsos positivos (ex: "cefaleia" na gripe injeta AVC/HSA).
    const _highRiskIds = {
      'avc_hemorragico', 'avc_isquemico', 'pcr_adulto', 'choque_cardiogenico',
      'hsa', 'meningite', 'sepse', 'iam_congestao', 'tep', 'status_epilepticus',
      // Protocolos com sintomas genéricos (cefaleia, náusea) no recognize:
      // exigem ≥2 palavras para evitar falso positivo em queries simples.
      'eclampsia_hellp', 'hiponatremia_grave', 'intox_monoxido_carbono',
      'caso_enxaqueca_aura', 'gripe_influenza_010',
    };

    final results = <String>[];
    final words = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    for (final p in protocolsDatabase) {
      final title    = _normalize(tDB(p.title));
      final recognize = _normalize(tDB(p.recognize));

      // Conta quantas palavras da query aparecem no título ou recognize
      final matchCount = words.where((w) => title.contains(w) || recognize.contains(w)).length;

      // Protocolo de alta emergência: exige ≥2 palavras para evitar falso positivo
      final isHighRisk = _highRiskIds.any((id) => p.id.contains(id));
      final minScore   = isHighRisk ? 2 : 1;

      if (matchCount >= minScore) {
        final actions = p.getActions(_lang).take(3).join(' | ');
        results.add('• [${tDB(p.title)}] Reconhecer: ${tDB(p.recognize).substring(0, tDB(p.recognize).length.clamp(0, 120))}... Conduta: $actions');
        if (results.length >= 4) break; // máx 4 protocolos para não exceder tokens
      }
    }
    return results;
  }

  /// Retorna sumários dos fármacos que correspondem à query
  List<String> _matchDrugs(String normalizedQuery) {
    final results = <String>[];
    for (final d in drugsDatabase) {
      final name  = _normalize(d.name);
      final cls   = _normalize(d.getField(d.className, _lang));
      final mech  = _normalize(d.getField(d.mechanism, _lang));
      final words = normalizedQuery.split(RegExp(r'\s+'))
          .where((w) => w.length > 3).toList();
      if (words.any((w) => name.contains(w) || cls.contains(w) || mech.contains(w))) {
        final dose = d.getField(d.fixedDose, _lang);
        final warn = d.getField(d.warning, _lang);
        results.add('• [${d.name}] Classe: ${d.getField(d.className, _lang)} | Dose: ${dose.isNotEmpty ? dose : "ver ficha"} | Alerta: ${warn.isNotEmpty ? warn.substring(0, warn.length.clamp(0, 80)) : "—"}');
        if (results.length >= 5) break; // máx 5 fármacos
      }
    }
    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLASSIFICADOR DE INTENT — detecta o tipo de consulta para RAG direcionado
  // ══════════════════════════════════════════════════════════════════════════

  /// Classifica o tipo de consulta para direcionar o pipeline RAG.
  /// Retorna string descritiva usada no system prompt como contexto para o Gemini.
  /// Classifica o intent em chave canônica curta usada pelo switch no system prompt.
  /// Ordem importa: mais específico antes de mais genérico.
  String _classifyIntent(String input) {
    final q = _normalize(input);

    // ── Referências bibliográficas ──────────────────────────────────────────
    if (_has(q, ['referencia', 'referencias', 'fonte ', 'fontes', 'bibliografia',
                  'bibliograf', 'citation', 'citar', 'quais fontes', 'qual fonte',
                  'baseado em que', 'evidencia usada', 'guideline usado'])) {
      return 'referencias';
    }

    // ── Fisiopatologia / mecanismo da doença ────────────────────────────────
    if (_has(q, ['fisiopatolog', 'patogenese', 'patogenia', 'mecanismo da doenca',
                  'mecanismo de doenca', 'mecanismo patolog', 'como ocorre a doenca',
                  'como se desenvolve', 'mecanismo fisio', 'fisiopatologia de',
                  'patofisiolog', 'por que ocorre a', 'porque ocorre a'])) {
      return 'fisiopatologia';
    }

    // ── Causas / etiologia ──────────────────────────────────────────────────
    if (_has(q, ['causa ', 'causas ', 'etiolog', 'fator de risco', 'fatores de risco',
                  'factor de riesgo', 'factores de riesgo', 'por que da ', 'porque da ',
                  'o que causa', 'que causa', 'origem de', 'precipita '])) {
      return 'causas';
    }

    // ── Prognóstico / seguimento ────────────────────────────────────────────
    if (_has(q, ['prognostico', 'prognosis', 'pronostico', 'sobrevida', 'mortalidade',
                  'mortalidad', 'seguimento', 'seguimiento', 'acompanhamento',
                  'fator de mau prognostico', 'factor de mal pronostico', 'sobrevivencia'])) {
      return 'prognostico';
    }

    // ── Interação medicamentosa ─────────────────────────────────────────────
    if (_has(q, ['interac', 'interage', 'junto com', 'junto a',
                  'associar com', 'associar a', 'compativel', 'combinacion', 'asociar'])) {
      return 'interacao';
    }

    // ── Emergência / urgência ───────────────────────────────────────────────
    if (_has(q, ['emergencia', 'urgencia', 'pcr ', 'parada cardiac',
                  'choque ', 'shock ', 'anafilax', 'status epilep', 'estado epilep',
                  'protocolo de emergencia', 'iam agudo', 'avc agudo', 'sepse grave'])) {
      return 'emergencia';
    }

    // ── Caso clínico — dados clínicos estruturados ──────────────────────────
    if (_has(q, ['paciente', 'pa ', 'fc ', 'spo2', 'glasgow', 'anos ', 'anos,',
                  'apresenta', 'presenta', 'admitido', 'ingresado', 'internado',
                  'temperatura', 'febre ', 'fiebre ']) &&
        input.trim().split(' ').length >= 6) {
      return 'caso_clinico';
    }

    // ── Tratamento / conduta ────────────────────────────────────────────────
    if (_has(q, ['tratamento', 'tratamiento', 'tratar ', 'tratar a', 'tratar o',
                  'conduta', 'conducta', 'manejo de', 'manejo da', 'manejo do',
                  'como tratar', 'como manejar', 'terapia para', 'terapia de',
                  'protocolo de tratamento', 'primeira linha', 'primera linea'])) {
      return 'tratamento';
    }

    // ── Farmacológica — sobre fármaco específico ou lista por indicação ─────
    if (_has(q, ['farmaco', 'farmacos', 'medicament', 'remedio ', 'remedios',
                  'droga ', 'antibiot', 'antibio', 'antiviral', 'antifungic',
                  'dose', 'dosagem', 'dosis', 'posolog', 'mecanismo de acao',
                  'mecanismo de accion', 'indicac', 'contraindicac',
                  'efeito adverso', 'efecto adverso', 'ajuste renal', 'gravidez'])) {
      return 'farmaco';
    }

    // ── Diagnóstico / critérios / definição ────────────────────────────────
    if (_has(q, ['diagnostico', 'diagnosticar', 'criterio', 'criterios',
                  'como diagnosticar', 'diagnostico diferencial', 'classificac',
                  'clasificacion', 'o que e ', 'que es ', 'definic', 'definicion',
                  'exame para diagnosticar', 'exame', 'laborator', 'interpretar'])) {
      return 'diagnostico';
    }

    return 'geral';
  }

  /// Verifica se a pergunta é uma query direta/nova (não deve herdar histórico)
  bool _isDirectQuery(String input) {
    final q = input.toLowerCase().trim();
    final directPrefixes = [
      'buscar em gemini:', 'buscar gemini:', 'buscar:', 'pesquisar:',
      'gemini:', 'ia:', 'perguntar:', 'consultar:',
      'search:', 'busca:', 'o que é ', 'o que e ',
      'qual é ', 'qual e ', 'como ', 'quando ', 'por que ', 'porque ',
      'explique ', 'explica ', 'defina ', 'define ',
    ];
    if (directPrefixes.any((p) => q.startsWith(p))) return true;
    final hasClinicalKeywords = _has(_normalize(input), [
      'paciente', 'dor', 'febre', 'dispne', 'tontura', 'choque',
      'pa ', 'fc ', 'spo2', 'glasgow', 'ecg', 'tomograf',
    ]);
    final isShortConceptual = input.trim().split(' ').length <= 6 && !hasClinicalKeywords;
    return isShortConceptual;
  }

  /// Constrói query expandida com contexto do histórico (últimas N msgs do usuário)
  /// Só expande se a pergunta for um follow-up clínico — nunca contamina queries novas
  String _expandedQuery(String currentInput, {int lastN = 3}) {
    // Perguntas diretas/novas: NÃO misturar histórico (evita resposta aleatória)
    if (_isDirectQuery(currentInput)) return currentInput.trim();

    // Follow-up clínico: expande com contexto recente
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    // Pega só as últimas N mensagens do usuário
    final tail = recentUserMsgs.length > lastN
        ? recentUserMsgs.sublist(recentUserMsgs.length - lastN)
        : recentUserMsgs;

    // Só inclui histórico se a pergunta for realmente um follow-up
    // (muito curta e sem contexto próprio — ex: "qual a dose?", "tem FA?")
    final isFollowUp = currentInput.trim().split(' ').length <= 5;
    if (!isFollowUp) return currentInput.trim();

    return '${tail.join(' ')} $currentInput'.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD AI ANSWER — Pipeline RAG Clínico
  //
  // Pipeline:
  //   1. Classificar intent (tipo de consulta)
  //   2. Expandir query com histórico relevante
  //   3. Retrieval local: matchProtocols + matchDrugs
  //   4. Análise local (fallback e contexto estruturado)
  //   5. Montar system prompt RAG com todos os contextos
  //   6. Chamar Gemini (com Google Search Grounding) ou OpenAI
  //   7. Salvar no histórico e retornar
  // ══════════════════════════════════════════════════════════════════════════
  Future<String> buildAIAnswer(String input) async {
    // ── Passo 1: Classificar intent ────────────────────────────────────────
    final intent        = _classifyIntent(input);
    final expandedInput = _expandedQuery(input);
    final normalized    = _normalize(expandedInput);

    // ── Passo 2: Retrieval local (protocolos + fármacos) ───────────────────
    final protocols = _matchProtocols(normalized);
    final drugs     = _matchDrugs(normalized);

    // Retrieval expandido: até 6 protocolos e 6 fármacos para casos complexos
    final protocolsExtended = _matchProtocolsExtended(normalized);
    final drugsExtended     = _matchDrugsExtended(normalized);

    final finalProtocols = protocolsExtended.isNotEmpty ? protocolsExtended : protocols;
    final finalDrugs     = drugsExtended.isNotEmpty ? drugsExtended : drugs;

    // ── Passo 3: Análise local estruturada (contexto para o Gemini) ────────
    final localContext = _buildLocalAnswer(input);

    // ── Passo 4: System prompt RAG completo ───────────────────────────────
    final systemPrompt = AiService.buildClinicalSystemPrompt(
      lang: _lang,
      matchedProtocolSummaries: finalProtocols,
      matchedDrugSummaries: finalDrugs,
      localAnswerContext: localContext,
      queryIntent: intent,
      patientAge: _patient.age.isNotEmpty ? _patient.age : null,
      patientSex: _patient.sex.isNotEmpty ? _patient.sex : null,
      patientWeight: _patient.weight.isNotEmpty ? _patient.weight : null,
      patientClcr: clcr,
      patientMedications: _patient.medications.isNotEmpty ? _patient.medications : null,
    );

    // ── Passo 5: Gemini (prioridade) com Google Search Grounding ──────────
    if (_geminiConnected) {
      // Garante API Key presente antes de chamar — pode ter sido perdida por reload
      if (!GeminiService.hasApiKey) {
        debugPrint('[buildAIAnswer] API Key ausente — tentando Firestore...');
        try {
          final geminiKey = await FirestoreService.loadGeminiApiKey()
              .timeout(const Duration(seconds: 5));
          if (geminiKey.isNotEmpty) {
            GeminiService.setGeminiApiKey(geminiKey); // persiste em SharedPrefs + mcLsSet
            debugPrint('[buildAIAnswer] API Key recarregada do Firestore ✓');
          } else {
            // Firestore vazio — SharedPreferences é o fallback primário (sem dart:js/eval)
            await GeminiService.initFromStorage();
            if (GeminiService.hasApiKey) {
              debugPrint('[buildAIAnswer] API Key restaurada do SharedPrefs ✓');
            }
          }
        } catch (e) {
          debugPrint('[buildAIAnswer] Firestore falhou: $e — tentando SharedPrefs...');
          await GeminiService.initFromStorage();
          if (GeminiService.hasApiKey) {
            debugPrint('[buildAIAnswer] API Key restaurada do SharedPrefs (fallback) ✓');
          }
        }
      }

      final geminiResult = await GeminiService.chat(
        userMessage: input,
        systemPrompt: systemPrompt,
        history: List.unmodifiable(_aiHistory),
        maxTokens: 1100,  // Ajustado para respostas abrangentes sem truncar
        useGrounding: true,
      );

      if (!geminiResult.isError) {
        _aiHistory
          ..add({'role': 'user', 'content': input})
          ..add({'role': 'assistant', 'content': geminiResult.text});
        while (_aiHistory.length > 20) _aiHistory.removeAt(0);
        return geminiResult.text;
      }

      // Gemini falhou — logar o erro para diagnóstico
      debugPrint('[buildAIAnswer] Gemini ERRO: code=${geminiResult.errorCode} text=${geminiResult.text.substring(0, geminiResult.text.length.clamp(0, 100))}');
      final localFallback = _buildLocalAnswer(input);
      // Se o contexto local tem conteúdo médico real (FASE 0/1/2a/2b/3) → exibir
      // Se é contexto interno técnico (FASE 2e/2f) → mostrar mensagem amigável
      final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
          localFallback.startsWith('INSTRUCAO_INTERNA') ||
          localFallback.startsWith('INSTRUCCION_INTERNA');

      switch (geminiResult.errorCode) {
        case 'api_key_invalid':
          return _lang == 'es'
              ? 'No se pudo conectar al asistente clínico. Verifica la configuración de la API. ⚕ Apoyo educacional.'
              : 'Não foi possível conectar ao assistente clínico. Verifique a configuração da API. ⚕ Apoio educacional.';
        case 'quota':
          return _lang == 'es'
              ? 'Límite de consultas alcanzado. Intenta nuevamente en unos minutos. ⚕ Apoyo educacional.'
              : 'Limite de consultas atingido. Tente novamente em alguns minutos. ⚕ Apoio educacional.';
        case 'blocked':
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
        default:
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
      }
    }

    // ── Passo 6: OpenAI (legado) ───────────────────────────────────────────
    if (_openAiKey.isEmpty) {
      final localFallback = _buildLocalAnswer(input);
      final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
          localFallback.startsWith('INSTRUCAO_INTERNA') ||
          localFallback.startsWith('INSTRUCCION_INTERNA');
      return isInternalContext
          ? (_lang == 'es'
              ? 'Hola. Para consultas clínicas, asegúrate de tener la API configurada. Puedo ayudarte con protocolos, fármacos y casos clínicos. ⚕ Apoyo educacional.'
              : 'Olá. Para consultas clínicas, certifique-se de ter a API configurada. Posso ajudar com protocolos, fármacos e casos clínicos. ⚕ Apoio educacional.')
          : localFallback;
    }

    final result = await AiService.chat(
      apiKey: _openAiKey,
      userMessage: input,
      systemPrompt: systemPrompt,
      history: List.unmodifiable(_aiHistory),
      maxTokens: 1100,  // Passo 6 OpenAI legado — mesmo limite do Gemini
    );

    if (result.isError) {
      switch (result.errorCode) {
        case 'invalid_key':
          return _lang == 'es'
              ? 'Clave de API inválida. Verifica la configuración en el menú. ⚕ Apoyo educacional.'
              : 'Chave de API inválida. Verifique a configuração no menu. ⚕ Apoio educacional.';
        case 'quota':
          return _lang == 'es'
              ? 'Límite de API alcanzado. Intenta nuevamente más tarde. ⚕ Apoyo educacional.'
              : 'Limite de API atingido. Tente novamente mais tarde. ⚕ Apoio educacional.';
        default: {
          final localFallback = _buildLocalAnswer(input);
          final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
              localFallback.startsWith('INSTRUCAO_INTERNA') ||
              localFallback.startsWith('INSTRUCCION_INTERNA');
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
        }
      }
    }

    _aiHistory
      ..add({'role': 'user', 'content': input})
      ..add({'role': 'assistant', 'content': result.text});
    while (_aiHistory.length > 20) _aiHistory.removeAt(0);
    return result.text;
  }

  // ── Retrieval estendido: retorna até 6 protocolos (para casos complexos) ──
  List<String> _matchProtocolsExtended(String normalizedQuery) {
    const _highRiskIds = {
      'avc_hemorragico', 'avc_isquemico', 'pcr_adulto', 'choque_cardiogenico',
      'hsa', 'meningite', 'sepse', 'iam_congestao', 'tep', 'status_epilepticus',
      'eclampsia_hellp', 'hiponatremia_grave', 'intox_monoxido_carbono',
      'caso_enxaqueca_aura', 'gripe_influenza_010',
    };
    final results = <String>[];
    final words = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    for (final p in protocolsDatabase) {
      final title    = _normalize(tDB(p.title));
      final recognize = _normalize(tDB(p.recognize));
      final matchCount = words.where((w) => title.contains(w) || recognize.contains(w)).length;
      final isHighRisk = _highRiskIds.any((id) => p.id.contains(id));
      final minScore   = isHighRisk ? 2 : 1;
      if (matchCount >= minScore) {
        final actions = p.getActions(_lang).take(4).join(' | ');
        results.add(
          '• [${tDB(p.title)}]\n'
          '  Reconhecer: ${tDB(p.recognize).substring(0, tDB(p.recognize).length.clamp(0, 180))}...\n'
          '  Conduta: $actions'
        );
        if (results.length >= 6) break;
      }
    }
    return results;
  }

  // ── Retrieval estendido de fármacos: retorna até 6 ─────────────────────
  List<String> _matchDrugsExtended(String normalizedQuery) {
    final results = <String>[];
    for (final d in drugsDatabase) {
      final name  = _normalize(d.name);
      final cls   = _normalize(d.getField(d.className, _lang));
      final mech  = _normalize(d.getField(d.mechanism, _lang));
      final words = normalizedQuery.split(RegExp(r'\s+'))
          .where((w) => w.length > 3).toList();
      if (words.any((w) => name.contains(w) || cls.contains(w) || mech.contains(w))) {
        final dose    = d.getField(d.fixedDose, _lang);
        final warn    = d.getField(d.warning, _lang);
        final mechStr = d.getField(d.mechanism, _lang);
        final route   = d.route;
        results.add(
          '• [${d.name}] ${d.getField(d.className, _lang)}\n'
          '  Mecanismo: ${mechStr.isNotEmpty ? mechStr.substring(0, mechStr.length.clamp(0, 120)) : "—"}\n'
          '  Dose: ${dose.isNotEmpty ? dose : "ver ficha"} | Via: ${route.isNotEmpty ? route : "—"}\n'
          '  Alerta: ${warn.isNotEmpty ? warn.substring(0, warn.length.clamp(0, 120)) : "—"}'
        );
        if (results.length >= 6) break;
      }
    }
    return results;
  }

  /// Resposta local (rule-based) enriquecida — serve como contexto RAG para o Gemini
  /// e como fallback autônomo quando não há IA disponível.
  ///
  /// ARQUITETURA:
  ///   FASE 0 — Farmacologia direta: resposta completa com mecanismo, dose, interações, alertas
  ///   FASE 1 — Sistema de pontuação por condição clínica (29 condições)
  ///   FASE 2 — Lógica contextual para queries sem match direto
  ///   FASE 3 — Render enriquecido: diferenciais, tratamento estruturado, doses, diretrizes
  ///
  /// OUTPUT: contexto estruturado markdown que o Gemini usa para gerar resposta final.
  String _buildLocalAnswer(String input) {
    final bool es = _lang == 'es';

    // ── Contexto do histórico (follow-up) ────────────────────────────────────
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    final historyTail = recentUserMsgs.length > 6
        ? recentUserMsgs.sublist(recentUserMsgs.length - 6)
        : recentUserMsgs;
    final qHistory  = _normalize(historyTail.join(' '));
    final qExpanded = _normalize('$qHistory $input');
    final q         = _normalize(input);

    // ════════════════════════════════════════════════════════════════════════
    // FASE 0b — FÁRMACOS POR INDICAÇÃO TERAPÊUTICA
    // Detecta queries do tipo "fármacos para cefaleia", "medicamentos para sepse"
    // Busca na drugsDatabase por group/className/categoria que corresponda à condição.
    // ════════════════════════════════════════════════════════════════════════
    final isIndicationQuery = _has(qExpanded, [
      'farma', 'medicament', 'remedio', 'drug ', 'farmaco',
      'medicamentos para', 'farmacos para', 'remedios para', 'drugs for',
    ]) && _has(qExpanded, [
      'para ', 'para a ', 'para o ', 'tratar ', 'tratamento de', 'tratamiento de',
      'indicado para', 'usar em', 'usar no', 'usar na',
    ]);

    if (isIndicationQuery) {
      // ── Mapa de condição → keywords para detecção na query (~150 condições) ──
      // Ordem importa: condições mais específicas primeiro para evitar falso match
      final conditionKeywords = <String, List<String>>{
        // ── EMERGÊNCIAS / CHOQUE ─────────────────────────────────────────────
        'anafilaxia':         ['anafilax', 'anafilact', 'choque anafilat', 'reacao alerg', 'reaccion alerg', 'adrenalina alerg', 'epinefrina alerg'],
        'choque_septico':     ['choque septic', 'choque septico', 'septic shock', 'vasopressor sepse', 'noradrenalina sepse'],
        'choque_cardiogenico':['choque cardiogen', 'cardiogenic shock', 'dobutamina choque', 'balao intra-aortic'],
        'choque_hipovolemico':['choque hipovol', 'hipovolem', 'hemorrag choque', 'reposicao volum'],
        'choque':             ['choque ', 'vasopressor', 'pam ', 'hipotens grave', 'noradrenalina '],
        'pcr':                ['pcr ', 'parada cardiac', 'reanimac', 'acls ', 'ressuscitac', 'fv ', 'tvsp'],
        // ── CARDIOVASCULAR ───────────────────────────────────────────────────
        'iam':                ['iam ', 'infarto agudo', 'sindrome coron', 'stemi', 'nstemi', 'sca ', 'angina instav', 'angina inestav'],
        'angina':             ['angina estav', 'angina cronic', 'angina pector', 'angina estable'],
        'ic':                 ['insuf cardiac', 'ic descomp', 'ic cronic', 'edema pulm', 'eap ', 'killip', 'fej ', 'frac ejec'],
        'fa':                 ['fibrilac atrial', 'fibrilacao atrial', 'flutter atrial', 'fa ', 'fibrila auricular', 'fibrilacion auricular'],
        'tpsv':               ['taquicardia supravent', 'tpsv ', 'tsv ', 'qrs estreit', 'reentrada nodal'],
        'tv':                 ['taquicardia ventricular', 'tv ', 'tvsp', 'tv polim', 'torsades', 'torsada pontas'],
        'bradicardia':        ['bradicard', 'bloqueio av', 'bav ', 'marcapasso', 'atropina bradicard'],
        'hipertensao':        ['hiperten', 'has ', 'pressao alta', 'pa alta', 'antihiperten', 'anti-hiperten'],
        'crise_hipertensiva': ['crise hiperten', 'emergencia hiperten', 'urgencia hiperten', 'encefalopatia hiperten', 'nitroprussi'],
        'dissecc_aorta':      ['dissecao aort', 'disseccao aort', 'diseccion aort', 'aneurisma aort'],
        'tep':                ['tromboembol pulm', 'embolia pulm', 'tep ', 'trombose pulm'],
        'tvp':                ['trombose venosa prof', 'tvp ', 'trombose venosa'],
        'endocardite':        ['endocardite', 'endocarditis', 'infeccao valv', 'bacteremia valv'],
        'miocardite':         ['miocardite', 'miocarditis', 'inflamacao miocardio'],
        'pericardite':        ['pericardite', 'pericarditis', 'derrame pericard', 'tamponament'],
        'cardiopatia_dilat':  ['cardiomiopatia dilat', 'cardiopatia dilat', 'miocardiopatia dilat'],
        'cardiopatia_hipert': ['cardiomiopatia hipert', 'miocardiopatia hipert'],
        // ── NEUROLÓGICO ─────────────────────────────────────────────────────
        'avc_isquemico':      ['avc isquem', 'acidente vasc isquem', 'ave isquem', 'acv isquem', 'trombolise avc', 'alteplase avc', 'trombectom'],
        'avc_hemorragico':    ['avc hemorr', 'hemorrag cerebr', 'hemorrag intracran', 'hic '],
        'hsa':                ['hemorrag subaracn', 'hsa ', 'cefaleia trovoada', 'cefaleia fulmin', 'aneurism roto'],
        'ait':                ['ait ', 'ataque isquem transit', 'acidente isquem transit', 'tia '],
        'epilepsia':          ['epileps', 'convuls', 'status epilep', 'crise epilep', 'crise convuls'],
        'meningite':          ['meningite', 'meningitis', 'encefalite', 'encephalitis', 'rigidez nuca', 'kernig', 'brudzinski'],
        'parkinson':          ['parkinson', 'dopamina defic', 'rigidez extrapiram', 'levodopa', 'carbidopa'],
        'alzheimer':          ['alzheimer', 'demencia alzhei', 'demencia progres', 'colinesterase'],
        'demencia':           ['demencia vasc', 'demencia ', 'comprometiment cognit', 'deterioro cognit'],
        'esclerose_mult':     ['esclerose mult', 'esclerosis mult', 'em ', 'desmielini', 'interferon beta'],
        'miastenia':          ['miastenia', 'myasthenia', 'fraqueza muscul progres', 'anticolin esterol'],
        'guillain_barre':     ['guillain', 'barre', 'polirradiculoneuri', 'paralisia ascend'],
        'enxaqueca':          ['enxaqueca', 'migranea', 'migraine', 'migrena', 'aura visual', 'triptano'],
        'cefaleia_tensional': ['cefaleia tensional', 'cefalea tensional', 'cefaleia tension', 'dor cabeca tensao'],
        'cefaleia':           ['cefal', 'cabeca', 'dor de cabeca', 'dolor de cabeza'],
        // ── RESPIRATÓRIO ────────────────────────────────────────────────────
        'pneumonia_com':      ['pneumonia comunid', 'pac ', 'pneumonia adquir', 'pneumonia tipic', 'pneumonia atipic', 'pneumonia viral'],
        'pneumonia_hosp':     ['pneumonia hospit', 'pah ', 'pneumonia associad ventil', 'pavm'],
        'tuberculose':        ['tuberculose', 'tuberculosis', 'tb ', 'mycobacterium tuberc', 'rifampicin', 'isoniaz'],
        'asma':               ['asma ', 'broncoespas', 'sibilo', 'wheezing', 'exacerbac asma', 'crise asma'],
        'dpoc':               ['dpoc', 'epoc', 'doenca pulm obstr', 'enfisema', 'bronquite cronic', 'exacerbac dpoc'],
        'insuf_resp':         ['insuf respirat', 'insuficiencia respirat', 'ira ', 'sdra', 'ards', 'ventilac mecan', 'intubac orotrac'],
        'pneumotorax':        ['pneumotorax', 'pneumotorox', 'neumotorax', 'pneumo torax'],
        'derrame_pleural':    ['derrame pleural', 'derrame pleural', 'pleurite', 'toracocentese'],
        'apneia_sono':        ['apneia sono', 'apnea sono', 'osas ', 'cpap apneia', 'ronco grave'],
        'covid':              ['covid', 'sars-cov', 'coronavirus', 'covid-19'],
        // ── INFECCIOSO ──────────────────────────────────────────────────────
        'sepse':              ['sepse', 'seps', 'septic', 'choque infeccioso', 'bacteremia', 'infec grave'],
        'itu':                ['infec urin', 'itu ', 'cistite', 'uretrite', 'bacteriuria'],
        'pielonefrite':       ['pielonefrit', 'pyelonefrit', 'infec renal', 'infec trato urin alto'],
        'celulite':           ['celulite infec', 'erisipela', 'celulitis infec', 'infec pele', 'infec tecid', 'ceftriaxona pele'],
        'fasceite':           ['fasceite necros', 'fascite necros', 'fasciitis necros', 'infec necros'],
        'osteomielite':       ['osteomielit', 'osteomyelit', 'infec ossea', 'infec osso'],
        'hiv_aids':           ['hiv', 'aids', 'antirretrovir', 'arvt', 'coquetel hiv'],
        'candidose':          ['candidiase sist', 'candidemia', 'candidiasis sistem', 'fungemias', 'antifungic sistemico'],
        'dengue':             ['dengue', 'arbovirose', 'aedes', 'dengue hemorrag'],
        'malaria':            ['malaria', 'malaria', 'plasmodium', 'cloroquina malaria', 'artemeter'],
        'leptospirose':       ['leptospirose', 'leptospirosis', 'ictericia febre'],
        'sifilis':            ['sifilis', 'syphilis', 'treponema', 'penicilina sifil'],
        'dst':                ['dst ', 'gonorreia', 'clamid', 'dst sexualment transmis'],
        'herpes_zoster':      ['herpes zoster', 'varicela zoster', 'nevralgia poster', 'aciclovir zoster'],
        'varicela':           ['varicela', 'chickenpox', 'varicela infec'],
        // ── GASTROINTESTINAL ────────────────────────────────────────────────
        // ── DIARREIA — índice completo ───────────────────────────────────────
        'diarreia':           [
          'diarr', 'diarrh',
          // tipos gerais
          'diarrea aguda', 'diarrea cronica', 'diarrea persist', 'diarrea refract',
          'diarrea osmotica', 'diarrea secretora', 'diarrea inflamat',
          'diarrea funcional', 'diarrea nocturna', 'diarrea posprandial',
          'diarrea acuosa', 'diarrea mucosa', 'diarrea sanguinolenta',
          'diarrea hemorrágica', 'diarrea hemorrhag', 'diarrea fulminant',
          'diarrea disenteric', 'diarrea febril', 'diarrea nosocomial',
          'diarrea esteatorreica', 'diarrea psicogena', 'diarrea autoimun',
          'diarrea endocrin', 'diarrea metabol',
          // infecciosa — bacteriana
          'diarrea infeccio', 'diarrea bacteriana', 'diarrea viral', 'diarrea parasitar',
          'diarrea viajero', 'traveler diarr', 'gastroenterite infec',
          'diarrea salmonela', 'salmonela diarr', 'salmonella diarr',
          'diarrea shigela', 'shigella diarr', 'shigela diarr', 'disenteria bacteriana',
          'diarrea campylobac', 'campylobacter diarr',
          'diarrea coli', 'escherichia coli diarr', 'e.coli enterot', 'etec ',
          'e.coli enterohemorrágica', 'ehec ', 'stec ', 'sindrome uremic hemolitic',
          'diarrea colera', 'vibrio cholerae', 'colera ', 'cholera ',
          'diarrea yersinia', 'yersinia enterocol',
          'diarrea clostridi', 'clostridioides difficile', 'clostridium difficile',
          'c. diff', 'cdiff ', 'colite por antibiot', 'colite pseudomembran',
          'diarrea antibiot', 'diarrea associada antibiot',
          // infecciosa — viral
          'rotavirus diarr', 'diarrea rotavirus',
          'norovirus diarr', 'diarrea norovirus', 'gastroenterite viral',
          'diarrea citomegalovirus', 'cmv intestinal',
          // infecciosa — parasitária
          'giardiase', 'giardiasis', 'giardia diarr',
          'amebiase', 'amebiasis', 'ameba diarr', 'entamoeba histol',
          'cryptosporidium diarr', 'diarrea cryptospor',
          'cyclospora diarr', 'isospora belli',
          // imunossuprimido / HIV
          'diarrea hiv', 'diarrea imunossuprim', 'diarrea paciente imuno',
          // pediátrica / neonatal
          'diarrea pediatric', 'diarrea neonatal', 'diarrea infant',
          // má absorção / maldigestão
          'diarrea malabsorcao', 'diarrea malabsorc', 'sindrome malabsorcao',
          'diarrea esteatorr', 'diarrea celiaca', 'doenca celiaca diarr',
          'diarrea intoler lactose', 'intolerancia lactose diarr',
          'insuf pancreatica exocrina', 'insuficiencia pancreatica diarr',
          'diarrea sobrecrescimento bact', 'sibo diarr', 'sobrecrescimento bacteriano',
          'sindrome intestino curto', 'diarrea intestino curto',
          'enteropatia perd proteina', 'diarrea proteina',
          'diarrea maldigest',
          // doenças inflamatórias intestinais
          'diarrea crohn', 'diarrea colite ulcerosa', 'diarrea dii',
          'colite microscopica', 'colite colagenos', 'colite linfocitica',
          'colite isquemica diarr',
          // induzida por medicamentos / procedimentos
          'diarrea metformina', 'diarrea medicamento',
          'diarrea ibp', 'diarrea inibidor bomba proton',
          'diarrea quimioterapia', 'diarrea oncologica',
          'diarrea imunoterapia', 'diarrea checkpoint',
          'diarrea radioterapia', 'diarrea radiacao',
          'diarrea sorbitol', 'diarrea magnesio', 'diarrea laxante',
          'diarrea nutricao enteral', 'diarrea enteral',
          'diarrea postoperat', 'diarrea posvagotomia', 'dumping syndrome diarr',
          'diarrea mucosit',
          // endócrina / tumoral
          'diarrea carcinoide', 'sindrome carcinoide diarr',
          'diarrea hipertireoid', 'hipertireoidismo diarr',
          'diarrea gastrinoma', 'zollinger ellison diarr',
          'diarrea feocromocitom', 'diarrea mastocitose',
          'diarrea insuf suprarenal', 'diarrea addison',
          'diarrea doenca whipple', 'whipple diarr',
          // alergia / eosinofílica
          'diarrea alergia aliment', 'diarrea eosinofil',
          // intoxicação alimentar
          'intoxicacao alimentar diarr', 'diarrea toxica',
          'intoxicacao mariscos', 'diarrea estafilococ',
          'bacillus cereus diarr', 'diarrea bacillus',
          'enterocolite neutropenic diarr',
          // tuberculose intestinal
          'tuberculose intestinal diarr', 'tb intestinal',
        ],
        // subtipos com manejo farmacológico distinto
        'diarreia_cdiff':     ['clostridioides difficile', 'clostridium difficile', 'c. diff', 'cdiff ', 'colite pseudomembran', 'colite por antibiot'],
        'diarreia_infecciosa':['diarrea viajero', 'traveler diarr', 'diarrea bacteriana aguda', 'gastroenterite bacteriana', 'salmonella diarr', 'shigella diarr', 'campylobacter diarr'],
        'diarreia_parasitaria':['giardiase', 'giardiasis', 'amebiase', 'amebiasis', 'cryptosporidium', 'cyclospora', 'isospora belli'],
        'diarreia_dii':       ['colite ulcerosa diarr', 'crohn diarr', 'diarrea dii', 'diarrea inflamat intest'],
        'diarreia_malabsorcao':['sindrome malabsorcao', 'celiac diarr', 'doenca celiaca', 'insuf pancreatica exocrina', 'sibo diarr', 'diarrea esteatorr'],
        'diarreia_funcional': ['diarrea funcional', 'diarrea sii', 'ibs diarr', 'sindrome intestino irritav diarr'],
        // ── ENDOCRINOLOGIA AVANÇADA ──────────────────────────────────────────
        'acromegalia':        ['acromegal', 'gigantismo', 'igf-1 elevad', 'gh elevad', 'adenoma somatotrop', 'tumor hipofis gh'],
        'adenoma_hipofis':    ['adenoma hipofis', 'adenoma pituitar', 'macroadenoma', 'microadenoma', 'tumor hipofise', 'prolactinoma', 'tumor sellar'],
        'prolactinoma':       ['prolactinoma', 'hiperprolactinemia', 'galactorreia', 'prolactina elevad'],
        'pan_hipopituitar':   ['pan-hipopituitar', 'hipopituitar', 'deficiencia hormonio hipofis', 'panhipopituitar'],
        'diabetes_insipidus': ['diabetes insipidus', 'diabetes insipid', 'poliuria polidipsia', 'desmopressin', 'adh defic', 'vasopressin defic'],
        'siadh':              ['siadh ', 'sindrome antiduret inapropriado', 'secrecao inapropriada adh', 'secrecao inapropiad antidiuret'],
        'hiperaldosteron':    ['hiperaldosteron', 'aldosteronoma', 'sindrome conn', 'adenoma adrenal', 'aldosterona elevad'],
        'hiperparatireoid':   ['hiperparatireoid', 'hiperparatiroid', 'pth elevado', 'adenoma paratireoid', 'hipercalcemia pth'],
        'hipoparatireoid':    ['hipoparatireoid', 'hipoparatiroid', 'pth baixo', 'hipocalcemia pth'],
        'neoplasia_endocr':   ['neplasia endocrina multipla', 'nem ', 'men ', 'neplasia endocrina multipla'],
        'carcinoide':         ['tumor carcinoide', 'sindrome carcinoide', 'tumor neuroendocr', 'serotonina tumo', 'carcinoid'],
        'insulinoma':         ['insulinoma', 'tumor celula beta', 'hipoglicemia hiperinsulinica', 'nesidioblastose'],
        'gastrinoma':         ['gastrinoma', 'zollinger ellison', 'gastrina elevad', 'hipergastrinemia'],
        'glucagonoma':        ['glucagonoma', 'glucagon tumor', 'eritema necrolit migratório'],
        'vipoma':             ['vipoma', 'diarrea acuosa hipopotassemia', 'sindrome verner-morrison'],
        // ── DOENÇAS RARAS / GENÉTICAS ────────────────────────────────────────
        'amiloidose':         ['amiloidose', 'amiloidosis', 'amiloide', 'deposito amiloid', 'ttr amiloid', 'polineuropatia amiloid'],
        'sarcoidose':         ['sarcoidose', 'sarcoidosis', 'granuloma sarcoid', 'lofgren', 'hilum adenopat bilateral'],
        'hemocromatose':      ['hemocromatose', 'hemochromatosis', 'sobrecarga ferro', 'ferritina muito elevad', 'deposito ferro'],
        'doenca_wilson':      ['wilson', 'doenca wilson', 'cobre deposito', 'kayser-fleischer', 'hepatolenticular'],
        'doenca_gaucher':     ['gaucher', 'glicocerebrosidase', 'glucocerebrosidase defic'],
        'doenca_fabry':       ['fabry', 'alfa galactosidase defic', 'angioqueratoma fabry'],
        'fenilcetonuria':     ['fenilcetonuria', 'fenilceton', 'pku ', 'fenilalanina elevad'],
        'mucopolissacarid':   ['mucopolissacarid', 'mucopolysaccharid', 'mps ', 'hurler', 'hunter sindrome'],
        'porfira':            ['porfiria', 'porphyria', 'dor abdominal porfiria', 'ataque agudo porf'],
        'sindrome_marfan':    ['marfan', 'sindrome marfan', 'aracnodactilia', 'ectopia lentis marfan'],
        'sindrome_ehlers':    ['ehlers danlos', 'ehlers-danlos', 'hipermobilidade articular'],
        'osteogenese_imp':    ['osteogenese imperfeit', 'osteogenesis imperfecta', 'osso fragil genetico'],
        'acondroplas':        ['acondroplasia', 'nanismo acondroplasia'],
        'sindrome_down':      ['sindrome down', 'trisomia 21', 'down sindromo'],
        'sindrome_klinef':    ['klinefelter', 'klinef', 'xxy ', '47 xxy'],
        'sindrome_turn':      ['turner', 'sindrome turner', 'monosson', '45 x'],
        'distrofia_muscul':   ['distrofia muscular', 'duchenne', 'becker distrofia', 'distrofia miotonica', 'miopatia genetica'],
        'ataxia':             ['ataxia ', 'ataxia espinocereb', 'ataxia friedreich', 'ataxia teleangiect'],
        'doenca_huntington':  ['huntington', 'coreia huntington', 'doenca huntington'],
        'als':                ['esclerose lateral amiotrofica', 'als ', 'ela ', 'doenca neuronio motor'],
        'sma':                ['atrofia muscular espinal', 'sma ', 'amea ', 'spinal muscular atrophy'],
        'pku':                ['fenilcetonuria', 'pku ', 'fenilalanina'],
        // ── REUMATOLOGIA AVANÇADA ────────────────────────────────────────────
        'espondilite':        ['espondilite anquilos', 'espondilitis anquilos', 'espondiloartrite', 'espondiloartrit', 'sacroileite', 'hla b27'],
        'artrite_psori':      ['artrite psori', 'artritis psori', 'artropatia psori'],
        'artrite_reativa':    ['artrite reativa', 'artritis reativa', 'sindrome reiter', 'artrite pos infec'],
        'artrite_idiopatica': ['artrite idiopatica juvenil', 'aij ', 'artrite juvenil'],
        'polimiosite':        ['polimiosite', 'polimiositis', 'dermatomiosite', 'miopatia inflamat'],
        'sindrome_sjogren':   ['sjogren', 'sjögren', 'xerostomia xeroft', 'sindrome sicca', 'olho seco boca seca autoimun'],
        'polimialgia_reum':   ['polimialgia reumat', 'pmr ', 'dor cintura escapular pelvic idoso'],
        'arterite_temporal':  ['arterite temporal', 'arterite celulas gig', 'arterite temporal craniana', 'cefaleia temporal idoso ceg'],
        'artrite_gota_agud':  ['artrite gotosa agud', 'podagra', 'artrite primeiro halux', 'monoartrit hiperuricemia'],
        'pseudogota':         ['pseudogota', 'condrocalcinose', 'deposito pirofosfato calcio'],
        'sindrome_antifosf':  ['sindrome antifosfolipide', 'saf ', 'anticardiolipina', 'anticoagul lupico', 'trombose autoimun'],
        'miopatia_inflam':    ['miosite', 'anticorpo anti-jo1', 'antissintetase', 'miopatia imunomediada'],
        'vasculite_anca':     ['vasculite anca', 'granulomatose poliangiite', 'poliangiite microscop', 'churg-strauss', 'eosinofilia vasculite'],
        'vasculite_takay':    ['takayasu', 'arterite takayasu', 'pulso ausente jovem'],
        'vasculite_kawas':    ['kawasaki', 'doenca kawasaki', 'febre mucocutanea linfonodal', 'aneurisma coronaria crian'],
        'behcet':             ['behcet', 'doenca behcet', 'ulcera oral genital uveit'],
        // ── NEUROLOGIA AVANÇADA ──────────────────────────────────────────────
        'neuropatia_perif':   ['neuropatia periferica', 'neuropatia perifer', 'polineuropatia', 'polineurit'],
        'neuropatia_diab':    ['neuropatia diabetic', 'neuropatia diabet', 'pe diabetico neuropatia'],
        'sindrome_carpal':    ['tunel carpal', 'sindrome tunel carpal', 'compressao nervo median'],
        'hernia_disco':       ['hernia disco', 'hernia discal', 'disco intervert', 'hernia nucleo pulposo', 'lombociatalgia'],
        'estenose_espin':     ['estenose espinhal', 'estenose canal', 'claudicacao neurogen'],
        'mielopatia':         ['mielopatia', 'myelopathy', 'compressao medular', 'medulopat'],
        'polineuropatia_desmiel': ['polineuropatia desmieli', 'pdci', 'cidp ', 'neuropatia inflamat cronic'],
        'neuropatia_optica':  ['neuropatia optica', 'neurite optica', 'nmo ', 'devic', 'neuromielite optica'],
        'encefalite_autoimun':['encefalite autoimun', 'encefalite anti-nmda', 'anti-nmda receptor', 'encefalite limbic'],
        'miopatia_mitocon':   ['miopatia mitocondrial', 'melas ', 'merrf ', 'disfuncao mitocondrial'],
        'esclerose_tuberosa': ['esclerose tuberosa', 'tuberous sclerosis'],
        'neurofibromat':      ['neurofibromatose', 'von recklinghausen', 'nf1 ', 'nf2 '],
        'acidente_mergulh':   ['doenca descompressao', 'embolia gasosa', 'acidente mergulhad'],
        'status_epileptico':  ['status epilepticus', 'status epilept', 'crise prolongada', 'estado epilep'],
        'hidrocefalia':       ['hidrocefalia', 'hidrocephaly', 'hidrocefal normotens', 'derivacao ventric'],
        'sindrome_guillain_miller':['miller fisher', 'sindrome fisher', 'oftalmoplegia ataxia arreflexia'],
        // ── PNEUMOLOGIA AVANÇADA ─────────────────────────────────────────────
        'fpi':                ['fibrose pulm idiopatica', 'fpi ', 'pneumopatia intersticial usual', 'uip ', 'ipf '],
        'sarcoidose_pulm':    ['sarcoidose pulmonar', 'granuloma pulmonar autoimun', 'adenopat mediastinal bilateral'],
        'hap':                ['hipertensao arterial pulm', 'hap ', 'pah ', 'hipertensao pulmonar primaria'],
        'bronquiectasia':     ['bronquiectasia', 'bronchiectasis', 'dilatacao brônquica'],
        'aspergilose':        ['aspergilose', 'aspergillus', 'aspergiloma', 'aspergilose alergica broncopulm'],
        'pneumocistose':      ['pneumocistose', 'pneumocystis jirovecii', 'pcp ', 'pneumonia jirovecii'],
        'pneumonia_eosinof':  ['pneumonia eosinofil', 'sindrome loeffler', 'eosinofilia pulm'],
        'hipertensao_pulm':   ['hipertensao pulmonar', 'hipertension pulmonar', 'cor pulmonale'],
        'quilotorax':         ['quilotorax', 'quilo torace', 'derrame pleural quiloso'],
        'mesotelioma':        ['mesotelioma', 'tumor pleura', 'mesothelioma'],
        'silicose':           ['silicose', 'pneumoconiose silio', 'doenca ocupacional pulm silicio'],
        'asbestose':          ['asbestose', 'asbestos', 'exposicao asbesto pulmao'],
        'mucoviscidose':      ['mucoviscidose', 'fibrose cistica', 'cystic fibrosis', 'cftr '],
        'deficit_a1at':       ['deficiencia alfa 1 antitripsina', 'alfa-1 antitripsina defic', 'a1at defic'],
        'hemossiderose':      ['hemossiderose', 'hemorragia alveolar', 'hemoptise difusa'],
        // ── GASTROINTESTINAL AVANÇADO ────────────────────────────────────────
        'doenca_celiaca':     ['doenca celiaca', 'celiac disease', 'enteropatia gluten', 'anti-ttg elevad', 'endomisio anticorp'],
        'enteropatia_prot':   ['enteropatia perd proteina', 'sindrome perd proteina intestinal', 'protein losing enteropathy'],
        'sobrecrescimento':   ['sobrecrescimento bacteriano', 'sibo ', 'sindrome intestino bacteri'],
        'colangite_primaria': ['colangite esclerosante primaria', 'cep ', 'psc ', 'estenose biliar inflamat autoimun'],
        'cirrh_biliar_prim':  ['cirrose biliar primaria', 'cbp ', 'pbc ', 'colangite biliar primaria', 'anti-m2 anticorp'],
        'hepatite_autoimun':  ['hepatite autoimun', 'hai ', 'hepatite cronic autoimun', 'anti-lkm1', 'anca fegato'],
        'esteatose_hepat':    ['esteatose hepatica', 'nafld', 'nash ', 'doenca gordurosa hepatica nao alcool', 'esteatohepatite'],
        'esofago_barrett':    ['barrett', 'esofago barrett', 'metaplasia intestinal esofago', 'esofago de barrett'],
        'acalasia':           ['acalasia', 'achalasia', 'espasmo esofago', 'disfagia motora', 'manometria esofago'],
        'angioectasia':       ['angioectasia', 'angiodisplasia', 'angiectasia intestinal', 'malformac vasc intestinal'],
        'isquemia_mesenteri': ['isquemia mesenter', 'infarto mesenter', 'angina mesenter', 'trombose mesenter'],
        'volvulo':            ['volvulo', 'vólvulo', 'rotacao intestino', 'obstrucao volvular'],
        'intussuscepcao':     ['intussuscepcao', 'invaginacao intestinal', 'invaginacion intestinal'],
        'paralisia_ileus':    ['ileus paralitico', 'suboclus intestinal', 'oclusao intestinal'],
        'hemorroidas':        ['hemorroida', 'hemorroids', 'hemorragia retal hemorroid'],
        'fissura_anal':       ['fissura anal', 'fissure anal', 'dor anal agud'],
        'cancer_esofago':     ['cancer esofago', 'carcinoma esofago', 'adenocarcinoma esofago', 'carcinoma escamos esofago'],
        'cancer_hepatico':    ['cancer hepatic', 'hepatocarcinoma', 'hcc ', 'carcinoma hepatocelular'],
        'cancer_biliar':      ['colangiocarcinoma', 'cancer biliar', 'cancer vias biliares'],
        // ── HEMATOLOGIA AVANÇADA ─────────────────────────────────────────────
        'anemia_aplasica':    ['anemia aplasica', 'aplasia medular', 'falha medular', 'pancitopenia aplasica'],
        'anemia_falciforme':  ['anemia falciforme', 'doenca falciforme', 'hemoglobina s', 'crise vasoclusiv', 'falciforme'],
        'talassemia':         ['talassemia', 'thalassemia', 'hemoglobina talassemia', 'talassemia alfa beta'],
        'mieloma':            ['mieloma multiplo', 'myeloma multiple', 'plasmocitoma', 'proteina bence jones', 'pico monoclon'],
        'mielof_primaria':    ['mielofibrose primaria', 'mielofibrose', 'myelofibrosis', 'fibrose medular'],
        'policitemia_vera':   ['policitemia vera', 'polycythemia vera', 'hematocrit elevad', 'jak2 mutacao'],
        'trombocitemia':      ['trombocitemia essencial', 'trombocitose reativa', 'plaquetas elevad'],
        'leucemia_linfoc':    ['leucemia linfoide cronic', 'llc ', 'cll ', 'linfocitose cronic'],
        'leucemia_mieloide':  ['leucemia mieloide cronic', 'lmc ', 'cml ', 'bcr-abl', 'filadelfia cromos'],
        'leucemia_aguda':     ['leucemia aguda', 'leucemia mieloide aguda', 'lma ', 'aml ', 'leucemia linfoide aguda', 'lla ', 'all '],
        'hemofilia':          ['hemofilia', 'hemophilia', 'fator viii defic', 'fator ix defic', 'coagulopatia heredit', 'sangramento articulac'],
        'von_willebrand':     ['von willebrand', 'doenca von willebrand', 'vwf defic'],
        'purpura_tromb':      ['purpura trombocitopenica trombot', 'ptt ', 'ttp ', 'microangiopatia trombotic'],
        'civd_aguda':         ['civd agud', 'coagulopatia consumo agud', 'civd sepse', 'civd obstetric'],
        'linfoma_hodgkin':    ['linfoma hodgkin', 'doenca hodgkin', 'celula reed-sternberg'],
        'linfoma_nhodgkin':   ['linfoma nao hodgkin', 'linfoma difuso grande celula', 'ldgcb ', 'dlbcl '],
        'mastocitose':        ['mastocitose', 'mastocytosis', 'urticaria pigmentosa adult'],
        'eosinofilia':        ['sindrome hipereosinofilica', 'eosinofilia primaria', 'eosinofilica grave'],
        'hemossiderose_pulm': ['hemossiderose pulmonar', 'hemorragia alveolar difusa'],
        // ── INFECTOLOGIA AVANÇADA ─────────────────────────────────────────────
        'mucormicose':        ['mucormicose', 'mucormycosis', 'zigomicose', 'zygomycosis', 'rhizopus infec'],
        'aspergilose_invas':  ['aspergilose invasiva', 'aspergillus invasivo', 'aspergilose imunossuprimido'],
        'cryptococcose':      ['cryptococcose', 'cryptococcus', 'meningite criptococica', 'meningite cryptoc'],
        'histoplasmose':      ['histoplasmose', 'histoplasma', 'infec histoplasma'],
        'coccidioidomicose':  ['coccidioidomicose', 'coccidioides', 'valley fever'],
        'blastomicose':       ['blastomicose', 'blastomyces'],
        'paracoccidioid':     ['paracoccidioidomicose', 'paracoccidioides brasilien', 'blastomicose sulamericana'],
        'sporotricose':       ['esporotricose', 'sporothrix', 'esporotricose felino'],
        'leishmaniose':       ['leishmaniose', 'leishmania', 'calazar', 'leishmaniose visceral', 'leishmaniose tegument'],
        'doenca_chagas':      ['doenca chagas', 'trypanosoma cruzi', 'chagas', 'cardiopatia chagasica'],
        'toxoplasmose':       ['toxoplasmose', 'toxoplasma gondii', 'toxoplasmose cerebral', 'encefalite toxoplasma'],
        'cmv_doenca':         ['citomegalovirus', 'cmv doenca', 'cmv invasivo', 'retinite cmv', 'colite cmv'],
        'ebv_doenca':         ['epstein barr', 'ebv ', 'mononucleose infec', 'sindrome mono'],
        'influenza':          ['influenza', 'gripe ', 'influenza a', 'influenza b', 'h1n1 ', 'h5n1'],
        'hepatite_a':         ['hepatite a', 'hav ', 'hepatite a aguda'],
        'hepatite_e':         ['hepatite e', 'hev ', 'hepatite e gestante'],
        'citomegalovirus':    ['cmv ', 'citomegalovirus infec', 'citomegal'],
        'raiva':              ['raiva ', 'rabie', 'lyssavirus'],
        'febre_amarela':      ['febre amarela', 'yellow fever', 'aedes febre amarela'],
        'zika':               ['zika', 'zika virus', 'microcefalia zika'],
        'chikungunya':        ['chikungunya', 'artralgia chikungunya', 'chikung'],
        'febre_tifoide':      ['febre tifoide', 'salmonella typhi', 'febre enteric'],
        'brucelose':          ['brucelose', 'brucella', 'febre ondulante'],
        'rickettsia':         ['rickettsia', 'febre maculosa', 'febre petequial'],
        'leishmaniose_cut':   ['leishmaniose cutanea', 'ulcera cutanea leishm', 'botao oriente'],
        'pneumocistis':       ['pneumocystis', 'pcp ', 'pneumonia pneumocystis', 'jirovecii'],
        'micobacteria_atip':  ['micobacteria atipica', 'mav ', 'mycobacterium avium', 'mac '],
        'nocardiose':         ['nocardiose', 'nocardia', 'nocardia pulm'],
        'actinomicose':       ['actinomicose', 'actinomyces', 'actinomicose cervicofacial'],
        'sindrome_shock_tox': ['sindrome choque toxico', 'toxic shock', 'tsst toxina', 'staphylococ shock'],
        'botulismo':          ['botulismo', 'clostridium botulinum', 'paralisia descendente'],
        'tetano':             ['tetano', 'tetanus', 'clostridium tetani', 'trismo tetano'],
        'difteria':           ['difteria', 'diphtheria', 'corynebacterium diphtheriae'],
        'coqueluche':         ['coqueluche', 'pertussis', 'bordetella pertussis', 'tosse convulsa'],
        'meningococcemia':    ['meningococcemia', 'neisseria meningit', 'meningococo', 'purpura fulminans'],
        'estafilococcemia':   ['staphylococcemia', 'bacteremia estafiloco', 'endocardite staph'],
        'e_coli_0157':        ['e coli 0157', 'ehec infec', 'stec infec', 'diarr hemorrágica e coli'],
        'tifo_murino':        ['tifo murino', 'rickettsia typhi', 'tifo endemico'],
        // ── CARDIOLOGIA AVANÇADA ─────────────────────────────────────────────
        'valvulopatia_aort':  ['valvulopatia aortic', 'estenose aortic', 'insuf aortic', 'regurgit aortic', 'valv aortic'],
        'valvulopatia_mitr':  ['valvulopatia mitral', 'estenose mitral', 'insuf mitral', 'prolapso mitral', 'regurgit mitral'],
        'valvulopatia_tric':  ['valvulopatia tricu', 'insuf tricuspide', 'estenose tricuspide'],
        'estenose_aortica':   ['estenose aortic', 'calcif valv aortic', 'tavi ', 'tavr '],
        'insuf_aortica':      ['insuf aortic', 'regurgit aortic', 'aorta insufici'],
        'insuf_mitral':       ['insuf mitral', 'regurgit mitral', 'prolapso mitral'],
        'estenose_mitral':    ['estenose mitral', 'area valv mitral reduz', 'mitral stenosis'],
        'cardiopatia_congen': ['cardiopatia congen', 'civ ', 'cia ', 'pca ', 'tetralogia fallot', 'coartacao aorta', 'transposicao grandes vasos'],
        'bloqueio_ramo':      ['bloqueio ramo esqu', 'bloqueio ramo dir', 'brd ', 'bre ', 'bloqueio fascicular'],
        'sindrome_qrs_longo': ['qt longo', 'qt prolongado', 'long qt syndrome', 'lqts ', 'torsades de pontes'],
        'wolf_parkinson':     ['wolf parkinson white', 'wpw ', 'pre-excitacao ventricular', 'delta wave'],
        'sind_brugada':       ['brugada', 'sindrome brugada', 'bloqueio ramo direito supra'],
        'arteriopatia_perif': ['arteriopatia periferica', 'dap ', 'isquemia membros infer', 'claudicac intermitente'],
        'aneurisma_aortico':  ['aneurisma aortico', 'aneurisma aorta abd', 'aneurisma aorta torac'],
        'pericardite_constr': ['pericardite constrit', 'pericardio constrit', 'pericardio calcific'],
        'mixoma_card':        ['mixoma cardiaco', 'tumor cardiaco', 'massa intracavit card'],
        'tumores_card':       ['tumor cardiaco', 'mixoma atrial', 'lipoma card', 'fibroelastoma'],
        'angina_microvascular':['angina microvascul', 'angina coronaria normal', 'sindrome x card'],
        'sind_tako_tsubo':    ['tako tsubo', 'cardiomiopatia estress', 'sindrome corac quebrado', 'apical balloon'],
        'hipertensao_resist': ['hipertensao resist', 'hipertensao refrat', 'ha resistente'],
        'hipertenso_renovasc':['hipertensao renovasc', 'estenose renal hiperten', 'hiper renal'],
        'sindrome_metabolica_card': ['risco cardiovasc metabolic', 'sindrome metabolic cardiovasc'],
        // ── NEFROLOGIA AVANÇADA ──────────────────────────────────────────────
        'glom_proliferat':    ['glomerulonefrite proliferat', 'glomerulon crescentic', 'nefrit agud'],
        'nefropatia_igA':     ['nefropatia iga', 'berger doenca', 'deposito iga renal'],
        'glom_membranosa':    ['glomerulonefrite membranosa', 'nefropatia membranosa', 'anti-pla2r'],
        'glom_focal_segm':    ['glom focal segment', 'gsfs ', 'focal glom'],
        'nefrop_diabetica':   ['nefropatia diabetica', 'microalbuminuria diabet', 'proteinuria diabetica'],
        'nefrite_lupica':     ['nefrite lupica', 'nefropatia lupica', 'renal lupus'],
        'polirrenal':         ['doenca policist renal', 'rim policist', 'dpr ', 'pkd ', 'cisto renal heredit'],
        'sindrome_alport':    ['alport', 'nefrite alport', 'surdez nefropatia heredit'],
        'tubulopatia':        ['tubulopatia', 'acidose tubular', 'sindrome fanconi renal'],
        'nefrocalcinose':     ['nefrocalcinose', 'deposito calcio renal', 'nefropatia hipercalcem'],
        'nefrotox_contraste': ['nefrotox contraste', 'nefropatia contraste', 'ira contraste iodad'],
        'nefrotox_aine':      ['nefrotox aine', 'ira aine', 'nefrite intersticial aine'],
        'glomnefr_ancianca':  ['glomnefrite anti-gBM', 'sindrome goodpasture', 'hemorragia pulm glomer'],
        'nefrite_intersticial':['nefrite intersticial', 'nin ', 'nefrite tubulo intersticial'],
        // ── DERMATOLOGIA AVANÇADA ────────────────────────────────────────────
        'acne':               ['acne', 'acne vulgar', 'acne severo', 'acne cistic', 'acne nodulocistic'],
        'rosacea':            ['rosacea', 'rosácea', 'eritema facial cronic', 'rinofima'],
        'penfigo':            ['penfigo', 'pemphigus', 'penfigo vulgar', 'penfigo foliace', 'bolha autoimun pele'],
        'penfigoide':         ['penfigoide bolhoso', 'bullous pemphigoid', 'bolha idoso'],
        'eritema_multiforme': ['eritema multiforme', 'stevens johnson', 'sindrome stevens johnson', 'necrolise epiderm tox', 'net '],
        'eritema_nodoso':     ['eritema nodoso', 'nodulo doloroso paniculite'],
        'urticaria_cronica':  ['urticaria cronica', 'urticaria cronica espontanea', 'uce '],
        'angioedema_heredit': ['angioedema heredit', 'angioedema c1q', 'inibidor c1 esterase defic', 'angioedema bradicinina'],
        'alopecia_areata':    ['alopecia areata', 'alopecia areata', 'queda cabelo autoimun', 'calvicie alopecia'],
        'onicomicose':        ['onicomicose', 'tinea unguium', 'fungo unhas'],
        'tinea':              ['tinea ', 'tinea capitis', 'tinea corporis', 'micose superficial', 'dermatofit'],
        'escabiose':          ['escabiose', 'sarna ', 'scabies ', 'sarcoptes'],
        'pediculose':         ['pediculose', 'piolho', 'pediculosis'],
        'herpes_simples':     ['herpes simples', 'hsv ', 'herpes labial', 'herpes genital', 'herpes oral'],
        'molluscum':          ['molluscum contagiosum', 'mollusco', 'molusco contagio'],
        'melanoma_skin':      ['melanoma pele', 'melanoma maligno cutaneo', 'lesao melanocit suspeita'],
        'cec_pele':           ['carcinoma espinoc celul', 'carcinoma celula escam pele', 'cec pele'],
        'cbc_pele':           ['carcinoma basocelu', 'carcinoma celula basal pele', 'cbc pele'],
        'dermatite_contact':  ['dermatite contato', 'dermatitis contacto', 'eczema contato'],
        'dermatite_sebor':    ['dermatite seborreica', 'caspa severa', 'eczema seborreico'],
        'liquen_plan':        ['liquen plano', 'lichen planus', 'liquen plan oral'],
        'vitiligo':           ['vitiligo', 'despigment autoimun', 'perda melanina'],
        'esclerose_tuberosa_skin': ['angiofibromas tuberosa', 'manchas pele esclerose tuberosa'],
        'xeroderma_pigm':     ['xeroderma pigmentos', 'fotossensibilidade cancer pele heredit'],
        // ── OFTALMOLOGIA ─────────────────────────────────────────────────────
        'glaucoma':           ['glaucoma', 'pressao ocular elevad', 'pio elevad', 'neuropatia optica glaucomat'],
        'catarata':           ['catarata', 'opacidade cristalino', 'cataract'],
        'degeneracao_macul':  ['degeneracao macul', 'dmar ', 'dme ', 'dmri ', 'degeneracao retinal central'],
        'retinop_diabetica':  ['retinopatia diabetica', 'retinop diabet', 'edema macul diabetico'],
        'descolamento_retin': ['descolamento retina', 'desprendimento retina', 'rotun retina'],
        'uveite':             ['uveite', 'uveitis', 'inflamac ocul interna', 'iritis', 'iridociclite'],
        'conjuntivite':       ['conjuntivite', 'conjunctivitis', 'olho vermelho agud'],
        'ceratite':           ['ceratite', 'queratite', 'keratitis', 'ulcera cornea'],
        'endoftalmite':       ['endoftalmite', 'endophthalmitis', 'infec intraocul grave'],
        'oclusao_retin':      ['oclusao arteria retin', 'oclusao veia retin', 'isquemia retinal'],
        'neuropatia_optica_isq': ['neuropatia optica isquemica', 'naion ', 'perda visao repentin idoso'],
        // ── OTORRINOLARINGOLOGIA ──────────────────────────────────────────────
        'otite_media':        ['otite media', 'otite media agud', 'oma ', 'infec ouvido medio'],
        'otite_externa':      ['otite extern', 'swimmer ear', 'otite externa difusa'],
        'sinusite':           ['sinusite', 'sinusitis', 'rinossinusite', 'sinusite bacteriana'],
        'faringite':          ['faringite', 'faringitis', 'amigdalite', 'tonsilite', 'dor garganta strep'],
        'laringite':          ['laringite', 'laringitis', 'disfonia infec', 'rouquidao infec agud'],
        'epistaxe':           ['epistaxe', 'sangramento nasal', 'epistaxis'],
        'tontura_labirint':   ['labirintite', 'tontura periferica', 'labirinto', 'vertigem periferica', 'vppb '],
        'meniere':            ['meniere', 'doenca meniere', 'vertigem flutuacao audicao'],
        'surdez_neurossens':  ['surdez neurossensorial', 'hipoacusia sensorioneural', 'perda auditiva nervosa'],
        'paralisia_facial':   ['paralisia facial', 'paralisia bell', 'bell palsy', 'paresia facial periferica'],
        'apneia_obstrutiva':  ['apneia obstrutiva sono', 'saos ', 'osas ', 'hipopneia obstrutiva', 'cpap indica'],
        // ── GINECOLOGIA E OBSTETRÍCIA AVANÇADA ────────────────────────────────
        'candidose_vaginal':  ['candidiase vaginal', 'candidose vaginal', 'vaginite candida', 'corrimento branco caseoso'],
        'vaginose_bact':      ['vaginose bacteriana', 'gardnerella', 'vb ', 'corrimento cinza peixe'],
        'tricomonas':         ['tricomonase', 'trichomonas', 'vaginite tricomonas'],
        'doip':               ['doenca inflamat pelv', 'dip ', 'pid ', 'infec pelv', 'salpingite', 'ooforite'],
        'gravidez_ectopica':  ['gravidez ectopica', 'gravidez tubaria', 'gestacao ectopica', 'ruptura tubaria'],
        'hipogalactia':       ['hipogalactia', 'insuf lactacao', 'pouco leite materno'],
        'mastite':            ['mastite', 'mastitis', 'infec mama puerperal'],
        'menopausa':          ['menopausa', 'menopausia', 'climateric', 'sintoma menopausa'],
        'osteoporose_menop':  ['osteoporose pos-menopausa', 'osteoporose mulher', 'fratura vertebral mulher'],
        'cancer_colo_utero':  ['cancer colo utero', 'carcinoma cervical', 'ca cervix', 'hpv cervix'],
        'cancer_utero':       ['cancer endometrio', 'cancer corpo utero', 'carcinoma endometrial'],
        'cancer_ovario':      ['cancer ovario', 'neoplasia ovario', 'carcinoma ovariano'],
        'mola_hidatiforme':   ['mola hidatiforme', 'neoplasia trofoblastica', 'doenca trofoblastica gestac'],
        'hiperemes_gravid':   ['hiperemese gravid', 'vomito incoercivel gravidez'],
        'colestase_gestac':   ['colestase gestacional', 'prurido gestacional', 'ictericia gestacional'],
        'diabetes_gestac':    ['diabetes gestacional', 'dmg ', 'glicemia gestacao'],
        // ── PEDIATRIA AVANÇADA ────────────────────────────────────────────────
        'febre_sem_foco':     ['febre sem foco crianca', 'febre pq crianca sem causa', 'fsf '],
        'desidratacao_ped':   ['desidratacao pediatrica', 'desidratacao crianca', 'crianca desidrataada'],
        'gastrenterite_ped':  ['gastrenterite pediatrica', 'gastroenterite crianca', 'diarr vomit crianca'],
        'pneumonia_ped':      ['pneumonia crianca', 'pneumonia pediatrica', 'pao pediatric'],
        'sepse_neonatal':     ['sepse neonatal', 'infec neonatal', 'sepsis neonatal', 'rn sepse'],
        'sindrome_resp_neo':  ['sindrome respiratoria neonatal', 'sindrome membrana hialina', 'smh '],
        'enterocolite_necrot':['enterocolite necrosante', 'necrotizing enterocolitis', 'ecn '],
        'hernia_diafragm':    ['hernia diafragmatica', 'hernia diafrag neonatal'],
        'estenose_piloro':    ['estenose hipertrofica piloro', 'estenose piloro', 'vomito projetil neonatal'],
        'atresia_esofago':    ['atresia esofago', 'fistula traqueoesofagica'],
        'hiperbilirrubin_neon':['hiperbilirrubinemia neonatal', 'ictericia neonatal', 'ictericia rn'],
        'tosse_ferina':       ['tosse ferina', 'pertussis ped', 'bordetella crian'],
        'sarampo':            ['sarampo', 'measles', 'paramixovirus sarampo'],
        'caxumba':            ['caxumba', 'parotidite epidemica', 'mumps'],
        'rubeola':            ['rubeola', 'rubella', 'rubeola congenita'],
        'escarlatina':        ['escarlatina', 'scarlet fever', 'streptococ exantema'],
        'doenca_mao_pe_boca': ['doenca mao pe boca', 'enterovirus exantema', 'mpbd '],
        'roseola':            ['roseola', 'exantema subito', 'hhv-6 exantema'],
        'crise_febril':       ['convuls febril', 'crise febril', 'convuls febre crian'],
        'autismo':            ['transtorno espectro autista', 'tea ', 'autism'],
        'tdah':               ['tdah ', 'adhd ', 'transtorno deficit atenc hiperativid'],
        'sindrome_west':      ['sindrome west', 'espasmos infantis', 'hipsarritmia'],
        'sindrome_dravet':    ['sindrome dravet', 'epilepsia mioclonica infan grave'],
        'prematuridade':      ['prematuridad', 'rn prematuro', 'prematuro ', 'prematuro extremo'],
        // ── UROLOGIA AVANÇADA ─────────────────────────────────────────────────
        'bexiga_hiperativa':  ['bexiga hiperativa', 'urge incontinencia', 'urge urinaria', 'incontinencia urge'],
        'incontinencia_urin': ['incontinencia urinaria', 'incontinence urine', 'perda urina', 'incontinencia urin'],
        'cistite_intersticial':['cistite intersticial', 'bexiga dolorosa', 'pia ', 'painful bladder'],
        'uretrolitiase':      ['ureterolitiase', 'calculo ureter', 'cólica ureteral'],
        'cancer_rim':         ['cancer renal', 'carcinoma celulas renais', 'ccr ', 'hipernefroma'],
        'cancer_bexiga':      ['cancer bexiga', 'carcinoma urotelial', 'tumor bexiga'],
        'varicocele':         ['varicocele', 'varicocele infertilid'],
        'orquite':            ['orquite', 'orchitis', 'infec testiculo'],
        'epididimite':        ['epididimite', 'epididymitis', 'infec epidid'],
        'torçao_testicular':  ['torcao testicular', 'torsao testis', 'escroto agudo'],
        'hidrocele':          ['hidrocele', 'acumulo liquido escroto'],
        'hipospadias':        ['hipospadias', 'uretra hipospad'],
        'fimose':             ['fimose', 'fimosis', 'preputio estreito'],
        'parafimose':         ['parafimose', 'paraphimosis', 'emergencia preputio'],
        // ── PSIQUIATRIA AVANÇADA ──────────────────────────────────────────────
        'adhd_adulto':        ['tdah adulto', 'adhd adulto', 'deficit atencao adulto'],
        'anorexia_nervosa':   ['anorexia nervosa', 'anorexia', 'transtorno alimentar restrit'],
        'bulimia':            ['bulimia nervosa', 'transtorno alimentar purga', 'bulimia'],
        'binge_eating':       ['compulsao alimentar', 'binge eating', 'transtorno compulsao aliment'],
        'personalidade_bord': ['transtorno personalidade borderline', 'tpb ', 'borderline personality'],
        'personalidade_antis':['transtorno personalidade antisocial', 'psicopatia', 'sociopatia'],
        'somatizacao':        ['somatizacao', 'transtorno somatoforme', 'somatoform', 'medicamente inexplicad'],
        'conversao':          ['transtorno conversao', 'sintoma neurologico funcional', 'histeria conversao'],
        'dismorfofobia':      ['dismorfofobia', 'bdd ', 'transtorno dismorfico corporal'],
        'jogo_patologico':    ['jogo patologico', 'ludopatia', 'gambling disorder'],
        'hipocondria':        ['hipocondria', 'ansied saude', 'transtorno ansied doenca'],
        'estress_agudo':      ['transtorno estress agudo', 'reacao aguda estress'],
        'luto_complica':      ['luto complicad', 'luto prolongad', 'luto patologico'],
        'insonia':            ['insonia', 'insomnia', 'disturbio sono insonia', 'dificuldade dormir'],
        'hipersonia':         ['hipersonia', 'sonolencia excessiva', 'narcolepsia', 'cataplexia'],
        'parassonia':         ['parassonia', 'terror noturno', 'sonambulismo', 'pesadelo parasso'],
        'mutismo_selet':      ['mutismo seletivo', 'mutismo select'],
        'fobia_especifica':   ['fobia especifica', 'fobia simples', 'medo especifico irrac'],
        'fobia_social':       ['fobia social', 'transtorno ansied social', 'social anxiety'],
        'alucinos_organica':  ['alucinose organica', 'delirium alucinac', 'alucinac organica'],
        // ── MEDICINA INTENSIVA / SUPORTE AVANÇADO ────────────────────────────
        'sdra':               ['sdra ', 'ards ', 'sindrome angust respirat agud', 'lesao pulm agud'],
        'hepatite_fulmin':    ['hepatite fulminante', 'falencia hepatica agud', 'hepatit agud grave'],
        'intox_paracetamol':  ['intox paracetamol', 'toxicidade paracetamol', 'toxicidade acetaminof', 'hepatotox paracetamol'],
        'intox_organofosfat': ['intox organofosfat', 'intox pesticida', 'crise colinergica', 'organofosf envenenamento'],
        'intox_monoxido':     ['intox monoxido carbono', 'intox co ', 'envenenamento co ', 'monoxido carbon'],
        'intox_metanol':      ['intox metanol', 'envenenamento metanol', 'acidose metabol anion gap alco'],
        'intox_etilenoglicol':['intox etileno glicol', 'envenenamento etileno glicol'],
        'intox_digoxina':     ['intox digoxina', 'toxicidade digoxina', 'digoxin toxicity'],
        'intox_litio':        ['intox litio', 'toxicidade litio', 'lithium toxicity'],
        'hipotermia':         ['hipotermia ', 'temperatura corp baix', 'hipothermia'],
        'hipertermia':        ['hipertermia maligna', 'golpe calor', 'heat stroke', 'temperatura elevad grave'],
        'afogamento':         ['afogamento', 'quase afogamento', 'submersao'],
        'mordedura':          ['mordedura animal', 'picada cobra', 'peconhento', 'envenenamento serpente'],
        'ferida_cirurgica':   ['infec ferida cirurgica', 'deiscencia ferida', 'infec sitio cirurgico'],
        'nutrição_parenteral':['nutricao parenteral total', 'npt ', 'nutrição parenter', 'nutrição iv'],
        'suporte_nutric':     ['suporte nutric', 'nutricao enteral', 'sonda enteral'],
        // ── CARDIOLOGIA INTERVENCIONISTA E ESTRUTURAL ─────────────────────────
        'angioplastia':       ['angioplastia coronaria', 'icp ', 'pci ', 'cateterismo intervenc', 'stent coronario'],
        'troca_valv':         ['substituicao valvular', 'cirurgia valva', 'troca valv'],
        'cirurgia_pontagem':  ['pontagem coronaria', 'cirurgia revascul miocardica', 'crm ', 'cabg '],
        'crt':                ['terapia ressincron cardiac', 'crt ', 'marcapasso biv', 'cdn implant'],
        'cardioversao':       ['cardioversao eletrica', 'cardioversao farmaco', 'cve ', 'desfibril'],
        'ablacao_cardiaca':   ['ablacao cardiaca', 'ablacao rf', 'ablacao fa'],
        // ── NUTRIÇÃO E METABOLISMO ─────────────────────────────────────────────
        'desnutricao':        ['desnutricao', 'malnutricao', 'deficit nutric', 'subnutricao'],
        'sarcopenia':         ['sarcopenia', 'perda massa muscul', 'dinapenia'],
        'defic_vitamina_d':   ['deficiencia vitamina d', 'hipovitaminose d', 'vitamina d insufic'],
        'defic_vitamina_b12': ['deficiencia vitamina b12', 'cobalamina defic', 'b12 baixo'],
        'defic_acido_folico': ['deficiencia folato', 'deficiencia acido folico', 'folato baix'],
        'defic_zinco':        ['deficiencia zinco', 'hipozincemia', 'acrodermatite enterop'],
        'defic_selenio':      ['deficiencia selenio', 'hiposeleniemia'],
        'defic_ferro':        ['deficiencia ferro', 'ferropenia', 'ferro baix'],
        'gota_alimentar':     ['gota alimentar', 'hiperuricemia dieta', 'artrite gotosa dieta'],
        // ── MEDICINA NUCLEAR / ONCOLOGIA AVANÇADA ─────────────────────────────
        'cancer_tireoide':    ['cancer tireoid', 'carcinoma papilif tireoid', 'carcinoma folicular tireoid', 'carcinoma medular tireoid'],
        'cancer_adrenal':     ['carcinoma adrenal', 'cancer gland adrenal', 'feocromocitom maligno'],
        'cancer_rim_avancado':['cancer renal metastat', 'ccr avancado', 'carcinoma renal metast'],
        'cancer_testicular':  ['cancer testicular', 'tumor germinativo', 'seminoma', 'nao seminoma testicular'],
        'cancer_peniano':     ['cancer penis', 'carcinoma penis'],
        'meduloblastoma':     ['meduloblastoma', 'tumor fosso posterior crian'],
        'glioblastoma':       ['glioblastoma', 'gbm ', 'glioblastoma multiforme', 'tumor cerebral maligno'],
        'astrocitoma':        ['astrocitoma', 'glioma baixo grau', 'glioma alto grau'],
        'meningioma':         ['meningioma', 'tumor meninges', 'meningioma cerebral'],
        'neuroblastoma':      ['neuroblastoma', 'tumor neural crianca'],
        'sarcoma':            ['sarcoma osseo', 'osteossarcoma', 'sarcoma ewing', 'sarcoma partes moles'],
        'carcinoma_espinocel_cabeca_pescoco': ['carcinoma cabeca pescoco', 'carcinoma espinocel cabeca', 'cancer laringe', 'cancer hipofaringe', 'cancer orofaringe'],
        'cancer_nasofaringe': ['cancer nasofaringe', 'carcinoma nasofaringeo', 'ebv nasofaringe'],
        'leucemia_celula_capilar': ['leucemia celula capilar', 'hairy cell leukemia', 'lcc '],
        'linfoma_burkitt':    ['linfoma burkitt', 'burkitt lymphoma', 'linfoma muito agressiv'],
        'linfoma_manto':      ['linfoma manto', 'mantle cell lymphoma', 'linfoma celula manto'],
        'linfoma_folicular':  ['linfoma folicular', 'follicular lymphoma', 'linfoma indolente'],
        'mieloma_amiloidose': ['mieloma amiloid', 'amiloidose al', 'amiloidose mieloma'],
        'leucemia_promielocit':['leucemia promielocitic agud', 'lpa ', 'apl ', 'm3 leucemia', 'pml rara'],
        'sindrome_mielodispl': ['sindrome mielodisplasic', 'smd ', 'mds ', 'citopenia medular displasica'],
        'cistite_hemorragica':['cistite hemorragica', 'hematuria pos quimio', 'cistite quimio radioterapia'],
        // ── TRANSPLANTES ─────────────────────────────────────────────────────
        'rejeicao_transplante':['rejeicao transplante', 'rejeicao organ', 'rejeicao agud transp'],
        'transplante_rim':    ['transplante renal', 'transplante rim', 'transplante renal pos-op'],
        'transplante_figado': ['transplante hepatico', 'transplante figado', 'transplante hepat pos-op'],
        'transplante_coracao':['transplante cardiaco', 'transplante coracao', 'transplante card pos-op'],
        'transplante_pulmao': ['transplante pulmonar', 'transplante pulmao'],
        'transplante_medula': ['transplante medula ossea', 'transplante celula trunc hematop', 'tcth ', 'tmo '],
        'doexa_enxerto_hosped':['doenca enxerto hospedeiro', 'gvhd ', 'deh '],
        // ── MEDICINA DO TRABALHO / OCUPACIONAL ────────────────────────────────
        'pneumoconiose':      ['pneumoconiose', 'doenca pulm ocupacional', 'lesao pulm poeira'],
        'saturnismo':         ['saturnismo', 'intox chumbo', 'lead poisoning', 'chumbo sanguine elevad'],
        'intox_mercurio':     ['intox mercurio', 'mercurialism', 'envenenamento mercurio'],
        'intox_arsenic':      ['intox arsenico', 'arsenicismo', 'envenenamento arsenio'],
        'burn_out':           ['burnout', 'esgotamento profissional', 'burn-out'],
        // ── FARMACOLOGIA CLÍNICA / INTERAÇÕES NOVAS ──────────────────────────
        'reacao_adversa':     ['reacao adversa medicamento', 'ram ', 'efeito adverso medicamento', 'toxicidade medicament'],
        'interacao_medicam':  ['interacao medicament', 'interacao drug', 'drug interaction', 'interacao farmacodin'],
        'polifarmacia':       ['polifarmacia', 'polimedicado', 'idoso multiplos medicam'],
        // ── GERIATRIA ─────────────────────────────────────────────────────────
        'sindrome_fragil':    ['sindrome fragilidade', 'fragil idoso', 'frailty', 'frailty sindrome'],
        'quedas_idoso':       ['quedas idoso', 'queda idoso', 'fratura por queda', 'prevencao quedas'],
        'demencia_lewy':      ['demencia lewy', 'corpos de lewy', 'demencia corpo lewy'],
        'demencia_front':     ['demencia frontotemporal', 'dft ', 'ftd ', 'demencia lobo frontal'],
        'delirium_idoso':     ['delirium idoso', 'confusao agud idoso', 'sd confusional agud idoso'],
        'incontinencia_fecal':['incontinencia fecal', 'incontinencia anal', 'perda fezes'],
        'constipacao_cronica':['constipacao cronica', 'obstipacao cronica', 'constipacao funcional adult'],
        'bexiga_neuropat':    ['bexiga neuropatica', 'disfuncao vesical neurogen', 'bexiga neurogen'],
        'sarcopenia_idoso':   ['sarcopenia idoso', 'perda massa muscul idoso'],
        'depressao_idoso':    ['depressao idoso', 'depressao geriat', 'depressao velhice'],
        // ── PNEUMOLOGIA CLÍNICA AVANÇADA ─────────────────────────────────────
        'dpa_alveolar':       ['proteinose alveolar pulm', 'pap ', 'preenchimento alveolar lipido'],
        'histiocitose':       ['histiocitose celula langerhans pulm', 'langerhans pulm'],
        'tromboembolia_cronic':['hipertensao pulm tromboembol cronic', 'hptec ', 'cteph '],
        'granulomatose_poliangiite': ['granulomatose poliangiite', 'wegener', 'vasculite anca pulm'],
        'pneumonia_organiz':  ['pneumonia organiz criptogen', 'cop ', 'boop '],
        'fibrosia_pulm_secund':['fibrose pulm secundaria', 'fibrose pulm colagenose', 'fibrose pulm ar'],
        // ── HEPATOLOGIA AVANÇADA ──────────────────────────────────────────────
        'hepatite_alcoolica': ['hepatite alcoolica', 'hepatopatia alcoolica agud', 'cirrose alcoolica agud'],
        'hepatite_toxica':    ['hepatite toxica', 'hepatotox medicamentosa', 'dili ', 'lesao hepatica medicat'],
        'encefal_hepatica':   ['encefalopatia hepatica', 'coma hepatic', 'asterixe hepatic'],
        'peritonite_bact':    ['peritonite bacteriana espontanea', 'pbe ', 'sbp '],
        'varizes_esofagicas': ['varizes esofagicas', 'hemorragia variz', 'sangramento variz esof'],
        'hiperesplenismo':    ['hiperesplenismo', 'esplenomeg hipercitopen', 'hipersecrestr esplenico'],
        'hepatite_cronica_b': ['hepatite b cronica', 'hbv cronica', 'hepatite b ativa'],
        'hepatite_cronica_c': ['hepatite c cronica', 'hcv cronica', 'hepatite c ativa'],
        'colangiocarc':       ['colangiocarcinoma', 'cancer via biliar intrahep', 'ca colangios'],
        'colelitiase':        ['colelitiase', 'calculo vesicular', 'pedra vesicula', 'litiase biliar'],
        // ── EMERGÊNCIAS ESPECIAIS ─────────────────────────────────────────────
        'hipertensao_intracran':['hipertensao intracraniana', 'hic ', 'pressao intracraniana elevad'],
        'herniacao_cerebral': ['herniacao cerebral', 'herniacao uncal', 'herniacao uncus', 'herniacao amigdala'],
        'morte_cerebral':     ['morte cerebral', 'morte encef', 'coma irreversivel', 'criterio morte encef'],
        'embolia_gordura':    ['embolia gordura', 'embolia lipidica', 'sindrome embolia gordura'],
        'sindrome_comp_abdom':['sindrome compartimento abdominal', 'pressao intra-abdom elevad', 'hia '],
        'crise_miastenia':    ['crise miastenica', 'fraqueza muscul respir miastenia', 'miastenia crise'],
        'crise_addisoniana':  ['crise addisoniana', 'insuf adrenal agud', 'crise adrenal', 'colapso adrenal'],
        'hipercalcemia_maligna':['hipercalcemia maligna', 'hipercalcemia cancer', 'hipercalcemia tumor'],
        'sind_lise_tumoral':  ['sindrome lise tumoral', 'slt ', 'tls ', 'lise tumoral quimio'],
        'neutropenia_grave':  ['neutropenia grave', 'agranulocitose', 'neutrofilo zero', 'infec neutropenia profund'],
        'hipoglicemia_grave': ['hipoglicemia grave', 'coma hipoglicem', 'hipoglicemia profund', 'glicemia muito baixo'],
        'crise_hipertens_renov':['crise hipertens renovasc', 'emergencia hiperten renal'],
        // ── MEDICINA DO ESPORTE / REABILITAÇÃO ────────────────────────────────
        'lesao_menisco':      ['lesao menisco', 'rotura menisco', 'menisco joelho'],
        'lesao_ligamento':    ['lesao ligamento', 'rotura lca', 'rotura lcd', 'ligamento joelho'],
        'tendinite':          ['tendinite', 'tendinopat', 'tendao inflamat', 'tendinite manguito'],
        'bursite':            ['bursite', 'bursitis', 'bolsa sinovial inflam'],
        'fasceite_plantar':   ['fasceite plantar', 'fascite plantar', 'dor calcaneo plantar'],
        'sindrome_dor_miof':  ['sindrome dor miofascial', 'ponto gatilho', 'trigger point'],
        'lombalgia':          ['lombalgia', 'dor lombar', 'lumbago', 'dorsalgia lombar'],
        'cervicalgia':        ['cervicalgia', 'dor cervical', 'cervicobrac'],
        'fibralgia':          ['fibromialgia', 'sensibilizac central', 'dor cronica difusa'],
        'rabdo_exercicio':    ['rabdomiolise exercicio', 'cak elevad exercicio', 'mioglobin pos exercicio'],
        // ── ALERGOLOGIA ──────────────────────────────────────────────────────
        'alerg_alimentar':    ['alergia alimentar', 'hipersensibilidade aliment', 'reacao alerg aliment'],
        'alerg_latex':        ['alergia latex', 'hipersensib latex'],
        'alerg_penicilina':   ['alergia penicilina', 'hipersensib betalact', 'alergia antibiotico'],
        'alerg_aspirina':     ['alergia aspirina', 'hipersensib aine', 'intolerancia aspirina'],
        'rinosinusite_alerg': ['rinosinusite alerg', 'rinite alerg', 'rinoconjuntivite alerg'],
        'asma_alerg':         ['asma alerg', 'asma atopica', 'asma alergen'],
        'asma_ocup':          ['asma ocupacional', 'asma agente trabalho'],
        'imunoterapia_alerg': ['imunoterapia alerg', 'dessensibilizac alergia', 'vacina alergia'],
        'mastocitose_sistem': ['mastocitose sistemica', 'mastocitose adulto', 'kit-d816v mastocit'],
        'eosinofilia_alerg':  ['eosinofilia periferica', 'eosinofilia alerg', 'sindrome eosinofilica'],
        // ── DOENÇAS AUTOIMUNES / IMUNOLOGIA ──────────────────────────────────
        'imunodefic_primaria':['imunodeficiencia primaria', 'agamaglobulinemia', 'imunodefic combina'],
        'imunodefic_comum':   ['imunodeficiencia comun variavel', 'idcv ', 'cvid '],
        'sindrome_wiskott':   ['wiskott aldrich', 'imunodefic wiskott', 'trombocitopen imunodefic'],
        'scid':               ['scid ', 'imunodefic combina grave', 'severe combined immunodefic'],
        'complemento_defic':  ['deficiencia complemento', 'defic c3 c4 c2', 'sistema complement defic'],
        'hiperiga':           ['hiper iga', 'hipergamaglobulinemia iga', 'iga elevad relapso infec'],
        'doenca_antifosfolip': ['doenca antifosfolipidio', 'saf ', 'trombose anticardiolipina', 'anticorpo antifosfolip'],
        // ── CARDIOMETABÓLICO ──────────────────────────────────────────────────
        'dislipidemia':       ['dislipidemia', 'hipercolesterol', 'ldl elevad', 'hdl baix', 'triglicerid elevad', 'hipertrigliceridemc'],
        'hipertriglicerid':   ['hipertrigliceridemia', 'triglicerid muito elevad', 'pancreatite hipertriglicerd'],
        'hipercolesterol_fam':['hipercolesterol familiar', 'hipercolesterol genetica', 'hf ', 'ldl muito elevad genetica'],
        'hiperuricemia':      ['hiperuricemia', 'acido urico elevad', 'uricemia elevad'],
        'resistencia_insul':  ['resistencia insulina', 'insulino resistente', 'hiperinsulinismo'],
        // ── CARDIOLOGIA CLÍNICA ADDITIONAL ────────────────────────────────────
        'taquicardia_sinusal':['taquicardia sinusal', 'taqui sinusal inapropriada', 'fc elevad sinusal'],
        'extrassistolia':     ['extrassistole', 'batimento ectopico', 'extrassistolia ventricular', 'extrassistolia atrial'],
        'flutteratrial':      ['flutter atrial', 'flutter auricular', 'flutter card'],
        // ── ENDOCRINOLOGIA ADICIONAL ──────────────────────────────────────────
        'hipoglicemia_reativa':['hipoglicemia reativa', 'hipoglicemia pos prandial', 'hipoglicemia alimentar'],
        'alcalose_metabol_cron':['alcalose metabol cronica', 'alcalose hipoklorem'],
        'acidose_tubular':    ['acidose tubular renal', 'atr ', 'acidose hipercloremk'],
        'hipomagnesemia':     ['hipomagnesemia', 'magnesio baix', 'mg+ baix'],
        'hipermagnesemia':    ['hipermagnesemia', 'magnesio elevad', 'mg+ elevad'],
        'hipofosfatemia':     ['hipofosfatemia', 'fosfato baix', 'hipofosfat'],
        'hiperfosfatemia':    ['hiperfosfatemia', 'fosfato elevad', 'hiperfosfat'],
        // ── DOENÇAS INFECCIOSAS EMERGENTES ───────────────────────────────────
        'mpox':               ['mpox', 'varíola dos macacos', 'monkeypox', 'varicela monkeypox'],
        'ebola':              ['ebola', 'virus ebola', 'febre hemorr ebola'],
        'mers':               ['mers ', 'sindrome respirat oriente medio', 'mers-cov'],
        'sars':               ['sars ', 'sindrome respirat aguda grave', 'sars-cov-1'],
        // ── DOENÇAS DO SONO ───────────────────────────────────────────────────
        'narcolepsia':        ['narcolepsia', 'cataplexia', 'sono excessivo diurno', 'paralisia sono'],
        'sindrome_pernas_inq':['sindrome pernas inquietas', 'spi ', 'rls ', 'movimento periodico membros'],
        'parassonias':        ['parassonias', 'sonambulismo adulto', 'terror noturno adulto', 'comportamento sono rem'],
        // ── MEDICINA HIPERBÁRICA / ESPECIAL ──────────────────────────────────
        'oxigenoterapia':     ['oxigenoterapia', 'suporte oxigenio', 'o2 suplementar', 'hipoxemia suporte'],
        'hiperbarica':        ['camara hiperbar', 'oxigenio hiperbarico', 'oht ', 'terapia hiperbar'],
        'hda':                ['hemorrag digest alta', 'hda ', 'hematemese', 'melena', 'varizes esof', 'sangram digest alto'],
        'hdb':                ['hemorrag digest baix', 'hdb ', 'hematoquez', 'sangram digest baix', 'rectorragia'],
        'pancreatite':        ['pancreatite', 'pancreatitis', 'lipase elevad', 'amilase elevad', 'necros pancrea'],
        'colecistite':        ['colecistite', 'colecistitis', 'calculo biliar', 'colelitias', 'colelitiasis'],
        'colangite':          ['colangite', 'colangitis', 'cole angite', 'infec biliar'],
        'apendicite':         ['apendicite', 'appendicitis', 'appendicite', 'mcburney'],
        'diverticulite':      ['diverticulit', 'diverticulosis complic'],
        'drge':               ['drge', 'reflux gastroesof', 'gerd', 'esofagite reflu', 'heartburn'],
        'ulcera_peptica':     ['ulcera peptic', 'ulcera gastric', 'ulcera duoden', 'h pylori', 'helicobacter'],
        'dii':                ['doenca inflamat intest', 'dii ', 'crohn', 'retocolite', 'colite ulcerosa'],
        'sii':                ['sindrome intest irritav', 'sii ', 'colon irritav', 'ibs '],
        'cirrose':            ['cirrose', 'cirrosis', 'hipertensao portal', 'ascite', 'encefalopatia hepat', 'hepatopatia cronic'],
        'hepatite':           ['hepatite viral', 'hepatite b', 'hepatite c', 'hepatitis viral', 'antiviral hepat'],
        'insuf_hepatica':     ['insuf hepatic', 'insuficiencia hepatic', 'falencia hepatic', 'necrose hepat massiv'],
        // ── RENAL ───────────────────────────────────────────────────────────
        'ira':                ['insuf renal agud', 'ira ', 'lesao renal agud', 'lra ', 'acute kidney', 'oliguria renal'],
        'drc':                ['doenca renal cronic', 'drc ', 'insuf renal cronic', 'nefropat cronic', 'dialise cronic'],
        'glomerulonefrite':   ['glomerulonefrit', 'glomerulonephrit', 'sindrome nefrit', 'hematuria glomeru'],
        'sindrome_nefrotica': ['sindrome nefrot', 'nefrose', 'proteinuria nefrot', 'hipoalbuminem'],
        'litíase_renal':      ['litias renal', 'calculo renal', 'nefrolitias', 'colica renal', 'colica nefret'],
        // ── ENDÓCRINO / METABÓLICO ──────────────────────────────────────────
        'dm1':                ['diabetes mellitus tipo 1', 'dm1', 'diabetes tipo 1', 'insulinodepend'],
        'dm2':                ['diabetes mellitus tipo 2', 'dm2', 'diabetes tipo 2', 'diabetes nao insulinodep'],
        'diabetes':           ['diabet', 'glicemia elevad', 'hiperglicemia', 'hipoglicemia'],
        'cad':                ['cetoacidos', 'cad ', 'dka ', 'acidose diabetic', 'cetose diabetic'],
        'ehnc':               ['estado hiperosmolar', 'ehnc ', 'ehh ', 'coma hiperosmolar', 'hiperglicemia grave'],
        'hipoglicemia':       ['hipoglicem', 'glicemia baix', 'coma hipoglicem', 'glucagom emerg'],
        'hipotireoidismo':    ['hipotireoid', 'hypothyroid', 'levotiroxin', 'tsh elevad'],
        'hipertireoidismo':   ['hipertireoid', 'hyperthyroid', 'tireotoxicos', 'tsh baixo', 'graves ', 'propiltiouracil'],
        'crise_tirotoxica':   ['crise tireotoxi', 'tempestade tireoid', 'thyroid storm'],
        'insuf_adrenal':      ['insuf adren', 'crisis adren', 'addison', 'cortisol baix', 'hidrocortisona crise'],
        'cushing':            ['cushing', 'hipercortisolism', 'cortisol exces'],
        'feocromocitoma':     ['feocromocitom', 'pheochromocytom', 'hipertensao parox', 'catecolamina exces'],
        'obesidade':          ['obesidade', 'sobrepeso', 'imc elevad', 'orlistat', 'liraglutida obesid'],
        // ── DISTÚRBIOS HIDROELETROLÍTICOS ────────────────────────────────────
        'hipercalemia':       ['hipercalemia', 'hiperpotassemia', 'k+ elevad', 'potassio elevad', 'kayexalat'],
        'hipocalemia':        ['hipocalemia', 'hipopotassemia', 'k+ baix', 'potassio baix', 'reposicao potassio'],
        'hiponatremia':       ['hiponatremia', 'sodio baix', 'na+ baix', 'hipoosm', 'siadh'],
        'hipernatremia':      ['hipernatremia', 'sodio elevad', 'na+ elevad', 'hiperosmolar sodio'],
        'hipocalcemia':       ['hipocalcemia', 'calcio baix', 'ca2+ baix', 'tetania', 'gluconato calcio'],
        'hipercalcemia':      ['hipercalcemia', 'calcio elevad', 'ca2+ elevad', 'hipercalc'],
        'acidose_met':        ['acidose metabol', 'acidose metabolica', 'bicarbonato baix', 'bicarbonato reposi'],
        'alcalose_met':       ['alcalose metabol', 'bicarbonato elevad'],
        'acidose_resp':       ['acidose respirat', 'hipercapnia', 'co2 elevad'],
        'alcalose_resp':      ['alcalose respirat', 'hipocapnia', 'co2 baix'],
        // ── HEMATOLOGIA / ONCOLOGIA ──────────────────────────────────────────
        'anemia_ferropriva':  ['anemia ferropriva', 'anemia ferropenic', 'deficiencia ferro', 'sulfato ferros', 'ferro defic'],
        'anemia_megalob':     ['anemia megaloblast', 'deficiencia b12', 'deficiencia folat', 'anemia perniciosa'],
        'anemia_hemol':       ['anemia hemolitic', 'hemolise', 'crise falciform', 'drepanocitos', 'esferocit'],
        'leucemia':           ['leucemia', 'leukemia', 'leucemia agud', 'blast leucem'],
        'linfoma':            ['linfoma', 'lymphoma', 'hodgkin', 'nao hodgkin'],
        'civd':               ['civd', 'coagulacao intravas dissemin', 'coagulopatia consumo'],
        'trombocitopenia':    ['trombocitopenia', 'plaqueta baix', 'pti ', 'purpura trombocitopen'],
        'neutropenia_febril': ['neutropenia febril', 'neutropenia ', 'febre neutropenia', 'mucosit febril'],
        // ── PSIQUIÁTRICO ─────────────────────────────────────────────────────
        'depressao':          ['depressao maior', 'depressao unipolar', 'tdm ', 'antidepressiv', 'isrs depressao'],
        'bipolar':            ['bipolar', 'mania ', 'episodio mania', 'lition', 'estabilizador humor'],
        'esquizofrenia':      ['esquizofrenia', 'schizophrenia', 'antipsicotic', 'alucinac', 'delirio psicot'],
        'ansiedade':          ['ansied', 'ansiet', 'tag ', 'transtorno ansied', 'generalizad'],
        'panico':             ['panico', 'panic', 'crise panico', 'ataque panico'],
        'tept':               ['tept', 'ptsd', 'trauma psiquiat', 'estresse pos-traum'],
        'toc':                ['toc ', 'transtorno obsessivo', 'ocd '],
        'intox_opioide':      ['intox opioide', 'intoxicacao opioide', 'overdose opioide', 'naloxona', 'naltrexona'],
        'intox_benzo':        ['intox benzodiazep', 'intoxicacao benzo', 'overdose benzo', 'flumazenil'],
        'intox_alcoolica':    ['intox alcoolic', 'embriaguez', 'alcoolismo agud'],
        'abstinencia_alcool': ['abstinencia alcool', 'withdrawal alcool', 'delirium tremens', 'tiamina alcool'],
        'sind_serotonin':     ['sindrome serotonin', 'serotonin syndrome', 'toxicidade serotonin'],
        'sind_neuroleptica':  ['sindrome neuroleptica', 'hipertermia neuroleptic', 'rigidez extrapiram febre'],
        'intoxicacao':        ['intox ', 'envenenamento', 'toxicolog', 'overdose', 'carvao ativad'],
        'delirium':           ['delirium', 'confusao agud', 'sindrome confusional', 'agitac psicomotor'],
        // ── REUMATOLÓGICO / MUSCULOESQUELÉTICO ───────────────────────────────
        'artrite_reuma':      ['artrite reumat', 'arthritis reumat', 'artrite reumatoide', 'ar ', 'metotrexato artrit'],
        'lupus':              ['lupus', 'les ', 'lupus eritematoso', 'hydroxicloroquina lupus'],
        'esclerodermia':      ['esclerodermia', 'scleroderma', 'esclerose sistem'],
        'vasculite':          ['vasculite', 'vasculitis', 'poliarterit', 'granulomatose wegener'],
        'gota':               ['gota ', 'artrite gotosa', 'hiperuricemia', 'colchicina', 'alopurinol'],
        'osteoartrite':       ['osteoartrit', 'osteoartrose', 'artrose', 'artrit degener'],
        'osteoporose':        ['osteoporose', 'osteoporosis', 'osteopenia', 'bifosfonato', 'alendronato'],
        'fibromialgia':       ['fibromialgia', 'fibromyalgia', 'dor cronico muscul', 'sensibilizacao central'],
        // ── GINECOLÓGICO / OBSTETRICO ────────────────────────────────────────
        'preeclampsia':       ['preeclampsia', 'pre-eclampsia', 'hellp', 'hipertensao gravidez'],
        'eclampsia':          ['eclampsia', 'convuls gravidez', 'gestante convuls'],
        'hemorragia_pp':      ['hemorragia pos-parto', 'hemorragia parto', 'atonia uterina', 'ocitocina hemorr'],
        'placenta_previa':    ['placenta previa', 'placenta baixa', 'sangramento placent'],
        'dpp':                ['descolamento placent', 'dpp ', 'abruptio placent'],
        'aborto_septico':     ['aborto septic', 'aborto infec', 'endometrit pos-aborto'],
        'sop':                ['sop ', 'sindrome ovar poliquistico', 'policistico ovar', 'metformina sop'],
        'endometriose':       ['endometriose', 'endometriosis'],
        // ── UROLÓGICO ───────────────────────────────────────────────────────
        'prostatite':         ['prostatite', 'prostatitis', 'infec prostat'],
        'hpb':                ['hiperplasia prostat', 'hpb ', 'bph ', 'obstruc urinaria'],
        // ── ONCOLÓGICO ──────────────────────────────────────────────────────
        'cancer_mama':        ['cancer mama', 'ca mama', 'carcinoma mama', 'quimio mama', 'hormoniot mama'],
        'cancer_pulmao':      ['cancer pulmao', 'carcinoma pulmao', 'nsclc', 'sclc', 'neoplasia pulm'],
        'cancer_gastrico':    ['cancer gastric', 'cancer estomago', 'adenocarcinoma gastric'],
        'cancer_colorret':    ['cancer colorret', 'cancer colon', 'cancer reto', 'neoplasia colorret'],
        'cancer_prostata':    ['cancer prostat', 'ca prostat', 'adenocarcinoma prostat'],
        'cancer_pancreas':    ['cancer pancreas', 'adenocarcinoma pancre', 'neoplasia pancreat'],
        'melanoma':           ['melanoma', 'neoplasia pele melanoc', 'ipilimumab melanom'],
        // ── PEDIÁTRICO ──────────────────────────────────────────────────────
        'bronquiolite':       ['bronquiolite', 'bronchiolitis', 'vsr ', 'sincicial respirat', 'bebes sibilos'],
        'crupe':              ['crupe', 'laringotraqueit', 'croup', 'dexametasona crupe'],
        // ── DERMATOLÓGICO ────────────────────────────────────────────────────
        'psoriase':           ['psoriase', 'psoriasis', 'placa eritematosa escam'],
        'dermatite_atopica':  ['dermatite atopic', 'eczema atopic', 'dermatitis atopic'],
        'urticaria':          ['urticaria', 'urticaria alerg', 'anti-histamin urtic'],
        // ── TRAUMA / CIRÚRGICO ───────────────────────────────────────────────
        'tce':                ['trauma cranioencefalic', 'tce ', 'traumatismo craniano', 'lesao cerebral traum'],
        'politrauma':         ['politrauma', 'trauma grave multipl', 'atls'],
        'queimaduras':        ['queimadura', 'queimadura ', 'burns ', 'escald'],
        'rabdomiolise':       ['rabdomiolise', 'rabdomyolysis', 'cpk elevad', 'mioglobin renal'],
        // ── MISCELÂNEA / GERAL ───────────────────────────────────────────────
        'sind_metabolica':    ['sindrome metabolic', 'resistencia insulin', 'dislipidemia obesi'],
        'sind_hepatorrenal':  ['sindrome hepatorrenal', 'shr ', 'hepatorenal'],
        'sind_cardiorrenal':  ['sindrome cardiorrenal', 'cardio renal'],
        'anticoag_reverter':  ['reverter anticoag', 'revertir anticoag', 'antidoto anticoag', 'sangramento anticoag'],
        'anticoagulacao':     ['anticoag', 'trombose', 'tvp ', 'tep ', 'embolia'],
        'nausea':             ['nause', 'vomit', 'antiemetic', 'enjoo grave'],
        'febre':              ['febre', 'fiebre', 'antipiret', 'hiperpirex'],
        'dor':                ['dor intens', 'dor cronic', 'analgesia', 'dor refrat', 'dor agud'],
        'infeccao':           ['infec ', 'antibiot', 'antibio', 'antimicrobiano', 'bacteriana'],
      };

      // ── Detectar qual condição está sendo perguntada ──────────────────────
      String? detectedCondition;
      for (final entry in conditionKeywords.entries) {
        if (entry.value.any((kw) => qExpanded.contains(kw))) {
          detectedCondition = entry.key;
          break;
        }
      }

      // ── Mapa condição → grupos/classes farmacológicas para busca na drugsDatabase ──
      final conditionToGroups = <String, List<String>>{
        // ── EMERGÊNCIAS / CHOQUE ────────────────────────────────────────────
        'anafilaxia':          ['adrenalina', 'epinefrina', 'adrenergic', 'anti-histamin', 'corticosteroid', 'difenidramina', 'broncodilatad', 'salbutamol'],
        'choque_septico':      ['vasopressor', 'noradrenalina', 'adrenalina', 'vasopressin', 'hidrocortisona', 'antibiotico', 'antibiot', 'antimicrobiano'],
        'choque_cardiogenico': ['inotrop', 'dobutamina', 'noradrenalina', 'milrinona', 'levosimendana', 'diuretico', 'furosemida', 'nitrato'],
        'choque_hipovolemico': ['cristaloide', 'coloide', 'albumina', 'acido tranexam', 'vasopressor'],
        'choque':              ['vasopressor', 'noradrenalina', 'adrenalina', 'dopamina', 'dobutamina', 'vasopressin', 'inotrop'],
        'pcr':                 ['adrenalina', 'epinefrina', 'amiodarona', 'atropina', 'bicarbonato', 'calcio cloreto', 'lidocaina'],
        // ── CARDIOVASCULAR ──────────────────────────────────────────────────
        'iam':                 ['antiagregant', 'antiplaquetario', 'aas', 'clopidogrel', 'ticagrelor', 'heparina', 'enoxaparina', 'nitrato', 'betabloqueant', 'ieca', 'estatina'],
        'angina':              ['nitrato', 'betabloqueant', 'bloqueador calcio', 'ranolazin', 'ivabradina', 'antiagregant', 'aas', 'estatina'],
        'ic':                  ['diuretico', 'furosemida', 'espironolactona', 'ieca', 'betabloqueant', 'sacubitril', 'digoxina', 'dobutamina', 'sglt2', 'nitroglicerin'],
        'fa':                  ['antiarritmico', 'amiodarona', 'betabloqueant', 'diltiazem', 'digoxina', 'anticoagul', 'rivaroxabana', 'apixabana', 'dabigatrana', 'warfarina'],
        'tpsv':                ['adenosina', 'betabloqueant', 'diltiazem', 'verapamil', 'antiarritmico', 'propafenona', 'flecainida'],
        'tv':                  ['amiodarona', 'lidocaina', 'procainamida', 'betabloqueant', 'sotalol', 'antiarritmico'],
        'bradicardia':         ['atropina', 'adrenalina', 'dopamina', 'isoproterenol', 'aminofilina'],
        'hipertensao':         ['anti-hipertensivo', 'ieca', 'bra', 'bloqueador calcio', 'diuretico', 'betabloqueant', 'amlodipino', 'captopril', 'losartana', 'enalapril', 'hidroclorotiazid'],
        'crise_hipertensiva':  ['nitroprussiato', 'nitroglicerin', 'labetalol', 'esmolol', 'hidralazina', 'nicardipino', 'furosemida'],
        'dissecc_aorta':       ['betabloqueant', 'esmolol', 'labetalol', 'nitroprussiato', 'nicardipino', 'morfina'],
        'tep':                 ['anticoagul', 'heparina', 'enoxaparina', 'rivaroxabana', 'apixabana', 'alteplase', 'trombolitic', 'fondaparinux'],
        'tvp':                 ['anticoagul', 'heparina', 'enoxaparina', 'rivaroxabana', 'apixabana', 'dabigatrana', 'warfarina'],
        'endocardite':         ['antibiotico', 'penicilina', 'ampicilina', 'oxacilina', 'gentamicina', 'vancomicina', 'rifampicina', 'antimicrobiano'],
        'miocardite':          ['betabloqueant', 'ieca', 'diuretico', 'corticosteroid', 'imunossupressor'],
        'pericardite':         ['antiinflamatorio', 'ibuprofeno', 'aine', 'colchicina', 'corticosteroid', 'aspirin'],
        'cardiopatia_dilat':   ['ieca', 'betabloqueant', 'diuretico', 'espironolactona', 'digoxina', 'sacubitril', 'anticoagul'],
        'cardiopatia_hipert':  ['betabloqueant', 'bloqueador calcio', 'disopiramida', 'amiodarona', 'anticoagul'],
        // ── NEUROLÓGICO ─────────────────────────────────────────────────────
        'avc_isquemico':       ['trombolitic', 'alteplase', 'antiagregant', 'clopidogrel', 'aas', 'anticoagul', 'estatina', 'anti-hipertensivo'],
        'avc_hemorragico':     ['anti-hipertensivo', 'labetalol', 'nicardipino', 'vitamina k', 'idarucizumabe', 'nimodipino'],
        'hsa':                 ['nimodipino', 'nicardipino', 'anti-hipertensivo', 'analgesic', 'antiemetic', 'corticoid'],
        'ait':                 ['antiagregant', 'clopidogrel', 'aas', 'anticoagul', 'estatina', 'anti-hipertensivo'],
        'epilepsia':           ['anticonvuls', 'antiepilep', 'benzodiazep', 'diazepam', 'midazolam', 'lorazepam', 'fenitoina', 'levetiracetam', 'valproato', 'carbamazepina', 'lamotrigina'],
        'meningite':           ['antibiotico', 'ceftriaxona', 'ampicilina', 'vancomicina', 'aciclovir', 'dexametasona', 'antimicrobiano'],
        'parkinson':           ['dopaminergic', 'levodopa', 'carbidopa', 'benserazida', 'pramipexol', 'rasagilina', 'entacapona'],
        'alzheimer':           ['inibidor colinesterase', 'donepezila', 'rivastigmina', 'galantamina', 'memantina'],
        'demencia':            ['donepezila', 'memantina', 'antipsicotic', 'inibidor colinesterase'],
        'esclerose_mult':      ['corticosteroid', 'metilprednisolona', 'interferon beta', 'acetato glatiramer', 'nataliz', 'fingolimod', 'imunossupressor'],
        'miastenia':           ['piridostigmina', 'neostigmina', 'corticosteroid', 'imunossupressor', 'azatioprina', 'micofenolato'],
        'guillain_barre':      ['imunoglobulina iv', 'ivig', 'anticoagul profilat', 'heparina'],
        'enxaqueca':           ['triptano', 'sumatriptano', 'rizatriptano', 'zolmitriptano', 'ergot', 'aine', 'paracetamol', 'dipirona', 'metoclopramida', 'propranolol', 'topiramato', 'amitriptilina', 'valproato'],
        'cefaleia_tensional':  ['aine', 'paracetamol', 'ibuprofeno', 'dipirona', 'amitriptilina', 'analgesic', 'relaxante muscul'],
        'cefaleia':            ['analgesic', 'aine', 'paracetamol', 'dipirona', 'ibuprofeno', 'triptano', 'antiemetic', 'metoclopramida'],
        // ── RESPIRATÓRIO ────────────────────────────────────────────────────
        'pneumonia_com':       ['antibiotico', 'amoxicilina', 'azitromicina', 'ceftriaxona', 'levofloxacino', 'ampicilina', 'amoxicilina-clavulanato'],
        'pneumonia_hosp':      ['antibiotico', 'piperacilin-tazobactam', 'meropenem', 'imipenem', 'vancomicina', 'amikacina'],
        'tuberculose':         ['rifampicina', 'isoniazida', 'pirazinamida', 'etambutol', 'antimicobacterian', 'antituberculoso'],
        'asma':                ['broncodilatad', 'beta2 agonist', 'salbutamol', 'formoterol', 'corticosteroid inalat', 'budesonida', 'fluticasona', 'ipratropio', 'teofilina', 'montelucaste'],
        'dpoc':                ['broncodilatad', 'salbutamol', 'ipratropio', 'tiotropio', 'formoterol', 'budesonida', 'roflumilaste', 'teofilina', 'corticosteroid sistem'],
        'insuf_resp':          ['broncodilatad', 'salbutamol', 'corticosteroid', 'antibiotico', 'diuretico', 'morfina'],
        'pneumotorax':         ['analgesic', 'morfina', 'aine'],
        'derrame_pleural':     ['diuretico', 'antibiotico', 'antiinflamatorio', 'aine'],
        'apneia_sono':         ['modafinil', 'teofilina', 'acetazolamida'],
        'covid':               ['corticosteroid', 'dexametasona', 'anticoagul', 'heparina', 'enoxaparina', 'remdesivir', 'nirmatrelvir', 'baricitinib', 'tocilizumab'],
        // ── INFECCIOSO ──────────────────────────────────────────────────────
        'sepse':               ['antibiotico', 'piperacilin-tazobactam', 'meropenem', 'imipenem', 'vancomicina', 'amikacina', 'noradrenalina', 'hidrocortisona'],
        'itu':                 ['antibiotico', 'nitrofurantoina', 'fosfomicina', 'ciprofloxacino', 'trimetoprim', 'cefalexina'],
        'pielonefrite':        ['antibiotico', 'ciprofloxacino', 'ceftriaxona', 'ampicilina', 'levofloxacino', 'gentamicina'],
        'celulite':            ['antibiotico', 'cefalexina', 'clindamicina', 'ceftriaxona', 'oxacilina', 'amoxicilina-clavulanato', 'vancomicina'],
        'fasceite':            ['antibiotico', 'piperacilin-tazobactam', 'meropenem', 'clindamicina', 'vancomicina'],
        'osteomielite':        ['antibiotico', 'ceftriaxona', 'oxacilina', 'vancomicina', 'ciprofloxacino', 'rifampicina'],
        'hiv_aids':            ['antirretrovir', 'tenofovir', 'emtricitabina', 'efavirenz', 'dolutegravir', 'atazanavir'],
        'candidose':           ['antifungico', 'fluconazol', 'anfotericin b', 'caspofungina', 'voriconazol', 'micafungina'],
        'dengue':              ['paracetamol', 'antipiret', 'analgesic', 'reposicao volum'],
        'malaria':             ['cloroquina', 'hidroxicloroquina', 'artemeter', 'lumefantrina', 'quinina', 'primaquina', 'doxiciclina'],
        'leptospirose':        ['penicilina g', 'doxiciclina', 'ampicilina', 'ceftriaxona'],
        'sifilis':             ['penicilina g benzatin', 'doxiciclina', 'azitromicina'],
        'dst':                 ['azitromicina', 'doxiciclina', 'ceftriaxona', 'penicilina', 'metronidazol'],
        'herpes_zoster':       ['aciclovir', 'valaciclovir', 'fanciclovir', 'antiviral', 'analgesic', 'gabapentina'],
        'varicela':            ['aciclovir', 'valaciclovir', 'anti-histamin', 'paracetamol'],
        // ── GASTROINTESTINAL ────────────────────────────────────────────────
        // ── DIARREIA — grupos farmacológicos por subtipo ─────────────────────
        'diarreia': [
          // reidratação e suporte
          'soro de reidratacao oral', 'sro', 'ringer lactato', 'solucao salina', 'reposicao voluminosa', 'zinc suplemento',
          // antidiarreicos / motilidade
          'loperamida', 'racecadotrila', 'bismuto subsalicilato',
          // antiespasmódicos
          'escopolamina', 'hioscina', 'mebeverina',
          // antibioticos gerais diarreia infecciosa
          'ciprofloxacino', 'azitromicina', 'cotrimoxazol', 'metronidazol',
          // probióticos
          'probiotico', 'lactobacillus', 'saccharomyces boulardii',
          // antieméticos
          'ondansetrona', 'metoclopramida', 'domperidona',
          // IBP se DRGE associado
          'omeprazol', 'pantoprazol',
          // anti-inflamatórios EII
          'mesalazina', 'sulfassalazina', 'corticosteroide',
          // antifúngicos/antiparasitários
          'metronidazol', 'tinidazol', 'albendazol', 'nitazoxanida',
          // enzimas pancreáticas
          'pancreatina', 'lipase pancreatica', 'creon',
          // colestiramina (diarreia por sais biliares)
          'colestiramina',
        ],
        'diarreia_cdiff': [
          'metronidazol oral', 'vancomicina oral', 'fidaxomicina',
          'bezlotoxumab', 'rifaximina', 'transplante microbiota fecal',
          'probiotico profilaxia', 'saccharomyces boulardii',
          'suspender antibiotico causador', 'loperamida contraindicada cdiff',
        ],
        'diarreia_infecciosa': [
          'ciprofloxacino', 'azitromicina', 'levofloxacino',
          'cotrimoxazol', 'ceftriaxona', 'ampicilina',
          'soro reidratacao oral', 'sro', 'ringer lactato',
          'loperamida', 'racecadotrila', 'bismuto subsalicilato',
          'ondansetrona',
        ],
        'diarreia_parasitaria': [
          'metronidazol', 'tinidazol', 'secnidazol',
          'nitazoxanida', 'albendazol', 'mebendazol',
          'paromomicina', 'iodoquinol',
          'cotrimoxazol', 'sulfadiazina',
        ],
        'diarreia_dii': [
          'mesalazina', 'sulfassalazina', 'corticosteroide',
          'budesonida', 'azatioprina', 'mercaptopurina',
          'infliximab', 'adalimumab', 'vedolizumab', 'ustekinumab',
          'metronidazol', 'ciprofloxacino',
          'anti-integrina', 'anti-tnf', 'anti-il12/23',
        ],
        'diarreia_malabsorcao': [
          'dieta sem gluten', 'pancreatina', 'creon', 'lipase pancreatica',
          'rifaximina sibo', 'antibiotico sibo', 'metronidazol sibo',
          'colestiramina', 'suplementacao vitaminas liposoluveis',
          'vitamina b12', 'acido folico', 'ferro reposicao',
          'enzima lactase', 'dieta sem lactose',
        ],
        'diarreia_funcional': [
          'loperamida', 'rifaximina', 'eluxadolina',
          'antidepressivo triciclico', 'ssri', 'mebeverina',
          'psyllium', 'colestiramina', 'ondansetrona',
          'dieta low fodmap',
        ],
        'hda':                 ['inibidor bomba proton', 'omeprazol', 'pantoprazol', 'octreotida', 'terlipressina', 'propranolol', 'antibiotico'],
        'hdb':                 ['mesalazina', 'infliximab', 'hemostasia endoscop'],
        'pancreatite':         ['analgesic', 'morfina', 'aine', 'reposicao volum', 'antibiotico', 'insulina'],
        'colecistite':         ['antibiotico', 'ceftriaxona', 'ampicilina', 'metronidazol', 'analgesic', 'escopolamina'],
        'colangite':           ['antibiotico', 'piperacilin-tazobactam', 'ampicilina', 'ciprofloxacino', 'metronidazol'],
        'apendicite':          ['antibiotico', 'ceftriaxona', 'metronidazol', 'piperacilin-tazobactam', 'analgesic'],
        'diverticulite':       ['antibiotico', 'ciprofloxacino', 'metronidazol', 'amoxicilina-clavulanato', 'analgesic'],
        'drge':                ['inibidor bomba proton', 'omeprazol', 'esomeprazol', 'pantoprazol', 'antiácido', 'metoclopramida', 'domperidona'],
        'ulcera_peptica':      ['inibidor bomba proton', 'omeprazol', 'pantoprazol', 'amoxicilina', 'claritromicina', 'metronidazol', 'bismuto'],
        'dii':                 ['mesalazina', 'sulfassalazina', 'corticosteroid', 'azatioprina', 'infliximab', 'adalimumab', 'metronidazol'],
        'sii':                 ['antiespasmódico', 'escopolamina', 'mebeverina', 'ssri', 'loperamida', 'lactulose'],
        'cirrose':             ['diuretico', 'furosemida', 'espironolactona', 'propranolol', 'lactulose', 'rifaximina', 'albumina', 'terlipressina'],
        'hepatite':            ['antiviral', 'interferon', 'ribavirina', 'sofosbuvir', 'daclatasvir', 'entecavir', 'tenofovir'],
        'insuf_hepatica':      ['lactulose', 'rifaximina', 'vitamina k', 'albumina', 'diuretico', 'n-acetilcisteina'],
        // ── RENAL ───────────────────────────────────────────────────────────
        'ira':                 ['diuretico', 'furosemida', 'bicarbonato', 'gluconato calcio', 'kayexalat', 'reposicao volum'],
        'drc':                 ['anti-hipertensivo', 'ieca', 'bra', 'diuretico', 'bicarbonato', 'eritropoetina', 'calcio carbonato', 'sevelamer'],
        'glomerulonefrite':    ['corticosteroid', 'imunossupressor', 'ciclofosfamida', 'micofenolato', 'anti-hipertensivo', 'diuretico'],
        'sindrome_nefrotica':  ['corticosteroid', 'prednisona', 'ciclofosfamida', 'diuretico', 'albumina', 'ieca'],
        'litíase_renal':       ['analgesic', 'aine', 'morfina', 'dipirona', 'tamsulosina', 'diclofenaco', 'escopolamina'],
        // ── ENDÓCRINO / METABÓLICO ──────────────────────────────────────────
        'dm1':                 ['insulina', 'insulina rapida', 'insulina nph', 'insulina glargin', 'insulina lispro'],
        'dm2':                 ['antidiabetic', 'metformina', 'glifozina', 'empagliflozin', 'liraglutida', 'sitagliptin', 'glibenclamida', 'insulina'],
        'diabetes':            ['insulina', 'metformina', 'antidiabetic', 'hipoglicemiant', 'glifozina'],
        'cad':                 ['insulina regular', 'solucao salina', 'potassio reposicao', 'bicarbonato'],
        'ehnc':                ['insulina regular', 'potassio reposicao', 'reposicao volum'],
        'hipoglicemia':        ['glicose hipertonic', 'glicose iv', 'glucagon', 'dextrose'],
        'hipotireoidismo':     ['levotiroxina', 'l-tiroxina', 'hormonio tiroid'],
        'hipertireoidismo':    ['propiltiouracil', 'metimazol', 'tiamazol', 'betabloqueant', 'propranolol', 'iodeto potassio'],
        'crise_tirotoxica':    ['propiltiouracil', 'propranolol', 'hidrocortisona', 'iodeto'],
        'insuf_adrenal':       ['hidrocortisona', 'fludrocortisona', 'dexametasona', 'corticosteroid'],
        'cushing':             ['ketoconazol', 'metirapona', 'mifepristona', 'pasireotida'],
        'feocromocitoma':          ['fenoxibenzamina', 'doxazosina', 'betabloqueant', 'bloqueador alfa', 'betabloqueant apos alfa', 'bloqueio alfa', 'metirosina'],
        'obesidade':           ['orlistat', 'liraglutida', 'semaglutida', 'bupropiona', 'topiramato'],
        // ── DISTÚRBIOS HIDROELETROLÍTICOS ────────────────────────────────────
        'hipercalemia':        ['gluconato calcio', 'bicarbonato sodio', 'insulina dextrose', 'salbutamol', 'kayexalat', 'patiromer', 'furosemida'],
        'hipocalemia':         ['cloreto potassio', 'potassio oral', 'potassio iv', 'reposicao potassio'],
        'hiponatremia':        ['solucao salina hiperton', 'nacl 3%', 'reposicao sodio', 'tolvaptan'],
        'hipernatremia':       ['solucao salina hipotonic', 'agua livre', 'dextrose 5%'],
        'hipocalcemia':        ['gluconato calcio', 'cloreto calcio', 'calcio iv', 'vitamina d'],
        'hipercalcemia':       ['solucao salina', 'furosemida', 'bisfosfonato', 'calcitonina', 'denosumab'],
        'acidose_met':         ['bicarbonato sodio', 'bicarbonato iv'],
        'alcalose_met':        ['cloreto potassio', 'acetazolamida'],
        'acidose_resp':        ['broncodilatad', 'corticosteroid'],
        'alcalose_resp':       ['analgesic', 'sedacao'],
        // ── HEMATOLOGIA / ONCOLOGIA ──────────────────────────────────────────
        'anemia_ferropriva':   ['sulfato ferroso', 'ferro polimaltosado', 'ferro iv', 'sacarato ferro', 'acido ascorbico'],
        'anemia_megalob':      ['cianocobalamina', 'vitamina b12', 'acido folico', 'hidroxicobalamina'],
        'anemia_hemol':        ['corticosteroid', 'prednisona', 'imunossupressor', 'acido folico', 'hidroxiureia'],
        'leucemia':            ['quimioterapia', 'imatinibe', 'dasatinibe', 'daunorubicina', 'citarabina'],
        'linfoma':             ['quimioterapia', 'rituximab', 'ciclofosfamida', 'doxorubicina', 'vincristina', 'prednisona'],
        'civd':                ['heparina', 'plasma fresco', 'crioprecipitado', 'acido tranexam'],
        'trombocitopenia':     ['imunoglobulina iv', 'corticosteroid', 'prednisona', 'rituximab', 'eltrombopag'],
        'neutropenia_febril':  ['antibiotico', 'ceftriaxona', 'piperacilin-tazobactam', 'meropenem', 'vancomicina', 'filgrastim'],
        // ── PSIQUIÁTRICO ─────────────────────────────────────────────────────
        'depressao':           ['antidepressiv', 'isrs', 'ssri', 'fluoxetina', 'sertralina', 'escitalopram', 'venlafaxina', 'bupropiona', 'amitriptilina'],
        'bipolar':             ['estabilizador humor', 'lition', 'valproato', 'lamotrigina', 'quetiapina', 'olanzapina', 'carbamazepina'],
        'esquizofrenia':       ['antipsicotic', 'haloperidol', 'risperidona', 'olanzapina', 'clozapina', 'quetiapina', 'aripiprazol'],
        'ansiedade':           ['ansiolitic', 'benzodiazep', 'diazepam', 'clonazepam', 'ssri', 'isrs', 'buspirona', 'venlafaxina', 'pregabalina'],
        'panico':              ['ssri', 'isrs', 'sertralina', 'fluoxetina', 'clonazepam', 'alprazolam'],
        'tept':                ['ssri', 'sertralina', 'paroxetina', 'prazosin'],
        'toc':                 ['ssri', 'fluoxetina', 'fluvoxamina', 'sertralina', 'clomipramina'],
        'intox_opioide':       ['naloxona', 'naltrexona'],
        'intox_benzo':         ['flumazenil'],
        'intox_alcoolica':     ['tiamina', 'vitamina b1', 'glicose', 'benzodiazep'],
        'abstinencia_alcool':  ['benzodiazep', 'diazepam', 'lorazepam', 'tiamina', 'haloperidol'],
        'sind_serotonin':      ['benzodiazep', 'ciproheptadina'],
        'sind_neuroleptica':   ['benzodiazep', 'bromocriptina', 'dantrolene'],
        'intoxicacao':         ['carvao ativad', 'naloxona', 'flumazenil', 'vitamina k', 'n-acetilcisteina', 'atropina'],
        'delirium':            ['haloperidol', 'quetiapina', 'rivastigmina', 'melatonin'],
        // ── REUMATOLÓGICO ───────────────────────────────────────────────────
        'artrite_reuma':       ['metotrexato', 'leflunomida', 'hidroxicloroquina', 'sulfassalazina', 'biologico', 'corticosteroid'],
        'lupus':               ['hidroxicloroquina', 'corticosteroid', 'azatioprina', 'micofenolato', 'ciclofosfamida', 'belimumab'],
        'esclerodermia':       ['sildenafil', 'bosentana', 'iloprost', 'ieca', 'omeprazol'],
        'vasculite':           ['corticosteroid', 'ciclofosfamida', 'rituximab', 'azatioprina'],
        'gota':                ['colchicina', 'aine', 'ibuprofeno', 'indometacina', 'prednisona', 'alopurinol', 'febuxostate'],
        'osteoartrite':        ['analgesic', 'aine', 'ibuprofeno', 'paracetamol', 'diclofenaco', 'condroitin', 'glucosamina'],
        'osteoporose':         ['bisfosfonato', 'alendronato', 'zoledronato', 'denosumab', 'teriparatida', 'calcio', 'vitamina d'],
        'fibromialgia':        ['amitriptilina', 'duloxetina', 'pregabalina', 'tramadol', 'ciclobenzaprina', 'gabapentina'],
        // ── GINECOLÓGICO / OBSTÉTRICO ────────────────────────────────────────
        'preeclampsia':        ['sulfato magnesio', 'hidralazina', 'labetalol', 'nifedipino', 'metildopa', 'betametasona'],
        'eclampsia':           ['sulfato magnesio', 'benzodiazep', 'diazepam', 'labetalol', 'nifedipino'],
        'hemorragia_pp':       ['ocitocina', 'ergometrina', 'misoprostol', 'acido tranexam'],
        'placenta_previa':     ['betametasona', 'tocolitic', 'nifedipino'],
        'dpp':                 ['betametasona', 'ocitocina', 'analgesic'],
        'aborto_septico':      ['antibiotico', 'ampicilina', 'gentamicina', 'metronidazol', 'ceftriaxona'],
        'sop':          ['metformina', 'anticoncept', 'espironolactona', 'citrato clomifeno', 'letrozol', 'anticoncept oral', 'semaglutida'],
        'endometriose':        ['progestagen', 'dienogest', 'leuprorelin', 'danazol', 'aine'],
        // ── UROLÓGICO ───────────────────────────────────────────────────────
        'prostatite':          ['antibiotico', 'ciprofloxacino', 'levofloxacino', 'doxiciclina', 'alfabloquead'],
        'hpb':                 ['alfabloquead', 'tamsulosina', 'doxazosina', 'dutasterida', 'finasterida'],
        // ── ONCOLÓGICO ──────────────────────────────────────────────────────
        'cancer_mama':         ['tamoxifeno', 'letrozol', 'anastrozol', 'trastuzumab', 'ciclofosfamida', 'doxorubicina', 'paclitaxel'],
        'cancer_pulmao':       ['erlotinib', 'gefitinib', 'osimertinib', 'pembrolizumab', 'cisplatina', 'carboplatina'],
        'cancer_gastrico':     ['5-fluorouracil', 'cisplatina', 'oxaliplatina', 'trastuzumab', 'ramucirumab'],
        'cancer_colorret':     ['5-fluorouracil', 'oxaliplatina', 'irinotecan', 'bevacizumab', 'cetuximab'],
        'cancer_prostata':     ['leuprorelin', 'bicalutamida', 'enzalutamida', 'abiraterona', 'docetaxel'],
        'cancer_pancreas':     ['gemcitabina', 'nab-paclitaxel', 'erlotinib'],
        'melanoma':            ['ipilimumab', 'pembrolizumab', 'nivolumab', 'vemurafenib', 'dabrafenib'],
        // ── PEDIÁTRICO ──────────────────────────────────────────────────────
        'bronquiolite':        ['salbutamol', 'broncodilatad', 'adrenalina'],
        'crupe':               ['dexametasona', 'budesonida', 'adrenalina', 'corticosteroid'],
        // ── DERMATOLÓGICO ───────────────────────────────────────────────────
        'psoriase':          ['metotrexato', 'corticosteroid', 'adalimumab', 'secuquinumab', 'apremilast', 'ciclosporina', 'corticosteroid topico', 'vitamina d topica', 'acitretina', 'biologico', 'secuquinumabe', 'guselkumabe', 'risankizumabe', 'tofacitinibe'],
        'dermatite_atopica':   ['corticosteroid topic', 'tacrolimus', 'dupilumab', 'anti-histamin', 'emoliente'],
        'urticaria':           ['anti-histamin', 'cetirizina', 'loratadina', 'fexofenadina', 'corticosteroid', 'adrenalina'],
        // ── TRAUMA / CIRÚRGICO ───────────────────────────────────────────────
        'tce':                 ['manitol', 'solucao salina hiperton', 'dexametasona', 'anti-hipertensivo', 'fenitoina'],
        'politrauma':          ['analgesic', 'morfina', 'fentanila', 'acido tranexam', 'antibiotico'],
        'queimaduras':         ['analgesic', 'morfina', 'fentanila', 'antibiotico', 'sulfadiazina'],
        'rabdomiolise':        ['reposicao volum', 'bicarbonato', 'manitol', 'furosemida'],
        // ── MISCELÂNEA ──────────────────────────────────────────────────────
        'sind_metabolica':          ['metformina', 'anti-hipertensivo', 'estatina', 'fibratos', 'exercicio', 'dieta'],
        'sind_hepatorrenal':   ['terlipressina', 'albumina', 'noradrenalina', 'antibiotico'],
        'sind_cardiorrenal':   ['diuretico', 'furosemida', 'dobutamina'],
        'anticoag_reverter':   ['vitamina k', 'protamina', 'idarucizumabe', 'andexanete', 'plasma fresco'],
        'anticoagulacao':      ['anticoagul', 'heparina', 'enoxaparina', 'warfarina', 'rivaroxabana', 'apixabana', 'dabigatrana'],
        'nausea':              ['antiemetic', 'ondansetrona', 'metoclopramida', 'droperidol', 'prometazina', 'domperidona'],
        'febre':               ['antipiret', 'paracetamol', 'dipirona', 'ibuprofeno', 'acido acetilsalicil'],
        'dor':                 ['analgesic', 'opioid', 'morfina', 'tramadol', 'paracetamol', 'dipirona', 'ibuprofeno', 'aine', 'fentanila'],
        'infeccao':            ['antibiotico', 'antimicrobiano', 'antifungico', 'antiviral'],
        // ── ENDOCRINOLOGIA AVANÇADA ──────────────────────────────────────────
        'acromegalia':         ['octreotida lar', 'lanreotida', 'pegvisomant', 'cabergolina', 'pasireotida', 'analago somatostatina', 'dopaminergico'],
        'adenoma_hipofis':     ['cabergolina', 'bromocriptina', 'octreotida', 'lanreotida', 'pasireotida', 'temozolomida', 'corticosteroid'],
        'prolactinoma':        ['cabergolina', 'bromocriptina', 'dopaminergico', 'agonista dopamina'],
        'pan_hipopituitar':    ['hidrocortisona', 'levotiroxina', 'desmopressina', 'hormonio crescimento', 'hormonio sexual reposicao'],
        'diabetes_insipidus':  ['desmopressina', 'ddavp', 'diuretico tiazidico di nefrogen', 'indometacina di nefrogen', 'amilorida'],
        'siadh':               ['restricao hidrica', 'nacl hipertonico', 'tolvaptan', 'satavaptan', 'urea oral siadh', 'demeclociclina'],
        'hiperaldosteron':     ['espironolactona', 'eplerenona', 'amilorida', 'anti-hipertensivo', 'adrenalectomia'],
        'hiperparatireoid':    ['cinacalcet', 'bisfosfonato', 'denosumab', 'hidratacao hipercalcemia', 'furosemida', 'calcitonina'],
        'hipoparatireoid':     ['calcio oral', 'calcio iv', 'vitamina d ativa', 'calcitriol', 'paratormonio recombinante', 'teriparatida'],
        'carcinoide':          ['octreotida', 'lanreotida', 'everolimus', 'interferon alfa', 'quimioterapia carcinoide'],
        'insulinoma':          ['diazoxida', 'octreotida', 'glucagon', 'glicose iv', 'verapamil', 'cirurgia insulinoma'],
        'gastrinoma':          ['inibidor bomba proton alta dose', 'omeprazol', 'octreotida', 'everolimus', 'streptozotocina'],
        'glucagonoma':         ['octreotida', 'zinco suplemento', 'quimioterapia', 'dieta baixo glucagon'],
        'vipoma':              ['octreotida', 'reposicao hidrica', 'corticosteroid', 'quimioterapia'],
        'neoplasia_endocr':    ['cirurgia', 'octreotida', 'corticosteroid', 'quimioterapia alvo especif', 'sunitinibe'],
        // ── DOENÇAS RARAS / GENÉTICAS ────────────────────────────────────────
        'amiloidose':          ['tafamidis', 'patisiran', 'inotersen', 'diflunisal', 'transplante orgao', 'melfalano', 'dexametasona amiloid'],
        'sarcoidose':          ['corticosteroid', 'metotreximo', 'azatioprina', 'hidroxicloroquina', 'infliximab', 'pentoxifilina'],
        'hemocromatose':       ['flebotomia', 'quelante ferro', 'deferoxamina', 'deferoprox'],
        'doenca_wilson':       ['d-penicilamina', 'trientina', 'zinco acetato', 'quelante cobre'],
        'doenca_gaucher':      ['imiglicerase', 'velaglicerase', 'miglustate', 'eliglustate', 'terapia enzimatica substitut'],
        'doenca_fabry':        ['agalsidase alfa', 'agalsidase beta', 'migalastate', 'terapia enzimatica substitut fabry'],
        'porfira':             ['hematina', 'glicose alta conc porfiria', 'analgesic', 'betabloqueant'],
        'sindrome_marfan':     ['betabloqueant', 'losartana', 'cirurgia aortica profilat', 'atenolol'],
        'distrofia_muscul':    ['corticosteroid', 'deflazacort', 'atalureno', 'eteplirsen', 'golodirsen', 'casimersen'],
        'als':                 ['riluzol', 'edaravona', 'tofersen', 'suporte respiratorio', 'suporte nutric'],
        'sma':                 ['nusinersen', 'onasemnogene abeparvovec', 'risdiplam', 'suporte respiratorio'],
        'doenca_huntington':   ['tetrabenazina', 'deutetrabenazina', 'valbenazina', 'antipsicotic', 'antidepressiv'],
        // ── REUMATOLOGIA AVANÇADA ────────────────────────────────────────────
        'espondilite':         ['aine', 'ibuprofeno', 'naproxeno', 'secuquinumabe', 'ixequizumabe', 'bimekizumabe', 'adalimumab', 'etanercept', 'certolizumab', 'ixekizumab', 'anti-tnf', 'anti-il17', 'upadacitinib', 'tofacitinib'],
        'artrite_psori':       ['metotrexato', 'secuquinumabe', 'ixequizumabe', 'adalimumab', 'etanercept', 'upadacitinib', 'guselkumabe', 'risankizumabe', 'anti-il17', 'anti-il23', 'anti-tnf'],
        'artrite_reativa':     ['aine', 'antibiotico', 'sulfassalazina', 'metotrexato', 'corticosteroid'],
        'artrite_idiopatica':  ['aine', 'metotrexato', 'corticosteroid', 'tocilizumab', 'etanercept', 'adalimumab', 'abatacepte'],
        'polimiosite':         ['corticosteroid', 'prednisona', 'azatioprina', 'metotrexato', 'micofenolato', 'imunoglobulina iv', 'rituximab'],
        'sindrome_sjogren':    ['hidroxicloroquina', 'pilocarpina', 'saliva artificial', 'colir umed', 'corticosteroid', 'rituximab'],
        'polimialgia_reum':    ['prednisona', 'corticosteroid', 'metotrexato', 'tocilizumab'],
        'arterite_temporal':   ['prednisona alta dose', 'corticosteroid', 'tocilizumab', 'metotrexato', 'aspirina antiagregant'],
        'sindrome_antifosf':   ['heparina', 'warfarina', 'rivaroxabana contraindicada', 'anticoagul', 'aspirina baixa dose', 'hidroxicloroquina'],
        'miopatia_inflam':     ['corticosteroid', 'imunossupressor', 'metotrexato', 'azatioprina', 'rituximab', 'imunoglobulina iv'],
        'vasculite_anca':      ['corticosteroid', 'ciclofosfamida', 'rituximab', 'azatioprina', 'metotrexato', 'avacopan'],
        'vasculite_takay':     ['corticosteroid', 'metotrexato', 'azatioprina', 'tocilizumab', 'infliximab'],
        'vasculite_kawas':     ['imunoglobulina iv alta dose', 'aspirina', 'corticosteroid', 'infliximab'],
        'behcet':              ['colchicina', 'corticosteroid', 'azatioprina', 'talidomida', 'infliximab', 'adalimumab', 'apremilast'],
        'pseudogota':          ['aine', 'colchicina', 'corticosteroid', 'aspiracao articular'],
        // ── NEUROLOGIA AVANÇADA ──────────────────────────────────────────────
        'neuropatia_perif':    ['vitamina b12', 'tiamina', 'pregabalina', 'gabapentina', 'duloxetina', 'amitriptilina', 'tramadol', 'capsaicina'],
        'neuropatia_diab':     ['pregabalina', 'duloxetina', 'gabapentina', 'amitriptilina', 'capsaicina', 'oxcarbazepina'],
        'sindrome_carpal':     ['corticosteroid local', 'imobilizacao', 'aine', 'cirurgia descompressao'],
        'hernia_disco':        ['aine', 'relaxante muscul', 'corticosteroid oral', 'gabapentina', 'ciclobenzaprina', 'cirurgia'],
        'polineuropatia_desmiel':['imunoglobulina iv', 'corticosteroid', 'plasmaferese', 'rituximab', 'azatioprina'],
        'neuropatia_optica':   ['corticosteroid iv', 'metilprednisolona', 'rituximab nmo', 'satralizumabe', 'inebilizumabe', 'eculizumabe'],
        'encefalite_autoimun': ['corticosteroid', 'imunoglobulina iv', 'plasmaferese', 'rituximab', 'micofenolato'],
        'status_epileptico':   ['benzodiazep iv', 'lorazepam iv', 'diazepam', 'levetiracetam iv', 'valproato iv', 'fenitoina iv', 'fenobarbital iv', 'propofol', 'midazolam infusao'],
        'hidrocefalia':        ['acetazolamida', 'furosemida', 'drenagem ventricular', 'derivacao ventricular'],
        'esclerose_tuberosa':  ['everolimus', 'vigabatrina', 'sirolimus', 'antiepilep'],
        'neurofibromat':       ['selumetinibe', 'cabozantinibe', 'cirurgia tumor'],
        'demencia_lewy':       ['donepezila', 'rivastigmina', 'memantina', 'evitar antipsicot tipico'],
        'demencia_front':      ['ssri', 'trazodona', 'memantina', 'rivastigmina', 'evitar benzod'],
        // ── PNEUMOLOGIA AVANÇADA ─────────────────────────────────────────────
        'fpi':                 ['pirfenidona', 'nintedanibe', 'n-acetilcisteina', 'antifibrot', 'suporte oxigenio'],
        'hap':                 ['sildenafil', 'tadalafil', 'bosentana', 'ambrisentana', 'macitentana', 'riociguate', 'iloprost', 'epoprostenol', 'selexipag', 'prostanoid'],
        'bronquiectasia':      ['antibiotico', 'azitromicina profilat', 'tobramicina inal', 'fisioterapia resp', 'colistina', 'dornase alfa'],
        'aspergilose':         ['voriconazol', 'isavuconazol', 'anfotericina b lipossomal', 'caspofungina', 'posaconazol'],
        'aspergilose_invas':   ['voriconazol', 'isavuconazol', 'anfotericina b lipossomal', 'micafungina', 'caspofungina'],
        'pneumocistose':       ['sulfametoxazol-trimetoprim', 'cotrimoxazol', 'pentamidina', 'atovaquona', 'clindamicina-primaquina'],
        'hipertensao_pulm':    ['sildenafil', 'bosentana', 'riociguate', 'diuretico', 'digoxina', 'anticoagul'],
        'mucoviscidose':       ['tobramicina inal', 'azitromicina', 'ivacaftor', 'lumacaftor', 'elexacaftor-tezacaftor-ivacaftor', 'dornase alfa', 'fisioterapia resp'],
        'deficit_a1at':        ['alfa-1 antitripsina exogen', 'suporte dpoc', 'broncodilatad', 'transplante pulmao'],
        'tromboembolia_cronic':['riociguate', 'anticoagul', 'endarterectomia pulm', 'angioplastia pulm balao'],
        'granulomatose_poliangiite':['rituximab', 'ciclofosfamida', 'corticosteroid', 'avacopan'],
        'pneumonia_organiz':   ['corticosteroid', 'prednisona', 'macrolid'],
        // ── HEMATOLOGIA AVANÇADA ─────────────────────────────────────────────
        'anemia_aplasica':     ['ciclosporina', 'imunoglobulina antitimocit', 'eltrombopag', 'transplante medula', 'danazol'],
        'anemia_falciforme':   ['hidroxiureia', 'voxelotor', 'crizanlizumabe', 'l-glutamina', 'transfusao', 'quelante ferro', 'transplante medula'],
        'talassemia':          ['transfusao', 'quelante ferro', 'deferoxamina', 'deferiprona', 'luspatercept', 'transplante medula', 'gene terapia'],
        'mieloma':             ['bortezomibe', 'lenalidomida', 'daratumumabe', 'carfilzomibe', 'pomalidomida', 'talidomida', 'dexametasona', 'melfalano', 'transplante celula trunc', 'belantamab'],
        'mielof_primaria':     ['ruxolitinibe', 'fedratinibe', 'pacritinibe', 'danazol', 'hidroxiureia', 'transplante medula'],
        'policitemia_vera':    ['flebotomia', 'hidroxiureia', 'ruxolitinibe', 'aspirina baixa dose', 'interferon alfa'],
        'trombocitemia':       ['hidroxiureia', 'anagrelida', 'aspirina', 'interferon alfa', 'ruxolitinibe'],
        'leucemia_linfoc':     ['ibrutinibe', 'venetoclax', 'obinutuzumabe', 'rituximab', 'bendamustina', 'clorambucil'],
        'leucemia_mieloide':   ['imatinibe', 'dasatinibe', 'nilotinibe', 'bosutinibe', 'ponatinibe', 'asciminibe'],
        'leucemia_aguda':          ['daunorubicina', 'citarabina', 'idarubicina', 'midostaurina', 'gemtuzumab', 'blinatumomabe', 'venetoclax', 'midostaurina flt3', 'gilteritinibe', 'azacitidina'],
        'hemofilia':           ['emicizumabe', 'fator viii recombinante', 'fator ix recombinante', 'fitusiran', 'concizumab', 'desmopressina hemofilia a leve'],
        'von_willebrand':      ['desmopressina', 'acido tranexam', 'fator von willebrand', 'caplacizumabe'],
        'purpura_tromb':       ['plasmaferese', 'caplacizumabe', 'rituximab', 'corticosteroid'],
        'mastocitose':         ['anti-histamin', 'cromoglicato sodio', 'ibrutinibe avancado', 'midostaurina', 'adrenalina emergencia'],
        'mastocitose_sistem':  ['midostaurina', 'avapritinibe', 'ibrutinibe', 'anti-histamin', 'cromoglicato'],
        'linfoma_hodgkin':          ['doxorubicina', 'bleomicina', 'vinblastina', 'dacarbazina', 'brentuximab vedotin', 'nivolumab', 'pembrolizumab', 'abvd', 'brentuximab'],
        'linfoma_nhodgkin':    ['rituximab', 'ciclofosfamida', 'doxorubicina', 'vincristina', 'prednisona', 'polatuzumab vedotin', 'axicabtagene'],
        'linfoma_burkitt':     ['quimioterapia intensiva', 'rituximab', 'metotrexato', 'citarabina'],
        'linfoma_manto':       ['ibrutinibe', 'acalabrutinibe', 'venetoclax', 'bortezomibe', 'rituximab', 'bendamustina'],
        'linfoma_folicular':   ['rituximab', 'obinutuzumabe', 'lenalidomida', 'bendamustina', 'quimioterapia ind'],
        'leucemia_promielocit':['acido trans-retinoico', 'atra ', 'trioxido arsenico', 'daunorubicina'],
        'sindrome_mielodispl': ['lenalidomida', 'luspatercept', 'azacitidina', 'decitabina', 'eritropoetina', 'transfusao', 'quelante ferro', 'transplante medula'],
        'leucemia_celula_capilar':['cladribina', 'pentostatina', 'rituximab', 'moxetumomab'],
        // ── INFECTOLOGIA AVANÇADA ─────────────────────────────────────────────
        'mucormicose':         ['isavuconazol', 'anfotericina b lipossomal', 'posaconazol', 'desbridamento cirurgico'],
        'cryptococcose':       ['anfotericina b', 'flucitosina', 'fluconazol', 'anfotericina b lipossomal'],
        'histoplasmose':       ['itraconazol', 'anfotericina b', 'voriconazol'],
        'paracoccidioid':      ['itraconazol', 'cotrimoxazol', 'sulfametoxazol', 'anfotericina b'],
        'leishmaniose':        ['meglumine antimoniat', 'antimoniato meglumina', 'anfotericina b lipossomal', 'miltefosina', 'pentamidina'],
        'doenca_chagas':       ['benznidazol', 'nifurtimox', 'amiodarona card chagasica', 'marcapasso', 'terapia ic'],
        'toxoplasmose':        ['pirimetamina', 'sulfadiazina', 'acido folinico', 'atovaquona', 'cotrimoxazol'],
        'cmv_doenca':          ['ganciclovir', 'valganciclovir', 'foscarnet', 'cidofovir'],
        'influenza':           ['oseltamivir', 'zanamivir', 'baloxavir', 'peramivir', 'corticosteroid grave'],
        'pneumocistis':        ['sulfametoxazol-trimetoprim', 'cotrimoxazol', 'pentamidina', 'atovaquona'],
        'micobacteria_atip':   ['azitromicina', 'claritromicina', 'etambutol', 'rifabutina', 'amikacina'],
        'nocardiose':          ['sulfametoxazol-trimetoprim', 'imipenem', 'amicacina', 'linezolida'],
        'botulismo':           ['antitoxina botulinica', 'suporte respiratorio', 'monitoramento intensivo'],
        'tetano':              ['imunoglobulina tetanica', 'penicilina', 'metronidazol', 'benzodiazep', 'baclofen'],
        'difteria':            ['antitoxina difteria', 'penicilina', 'eritromicina', 'macrolid'],
        'coqueluche':          ['azitromicina', 'eritromicina', 'cotrimoxazol', 'suporte resp'],
        'meningococcemia':     ['ceftriaxona', 'penicilina', 'corticosteroid', 'vasopressor'],
        'rickettsia':          ['doxiciclina', 'tetraciclina', 'cloranfenicol'],
        'febre_tifoide':       ['ceftriaxona', 'ciprofloxacino', 'azitromicina', 'ampicilina'],
        'brucelose':           ['doxiciclina', 'rifampicina', 'gentamicina', 'cotrimoxazol'],
        'ebv_doenca':          ['aciclovir', 'corticosteroid', 'suporte sintomatic'],
        'zika':                ['analgesic', 'paracetamol', 'suporte', 'evitar aine'],
        'chikungunya':         ['paracetamol', 'aine fase cronica', 'hidroxicloroquina cronica', 'corticosteroid local'],
        'febre_amarela':       ['suporte sintomatic', 'transfusao', 'nao tem antiviral especif'],
        'mpox':                ['tecovirimat', 'cidofovir', 'brincidofovir', 'imunoglobulina vaccinia'],
        'sporotricose':        ['itraconazol', 'anfotericina b sistemico', 'supersaturado iod potassio'],
        'sindrome_shock_tox':  ['penicilina', 'clindamicina', 'vancomicina', 'imunoglobulina iv', 'fluido ressuscit'],
        'leishmaniose_cut':    ['meglumine antimoniat local', 'fluconazol', 'miltefosina'],
        // ── CARDIOLOGIA AVANÇADA ─────────────────────────────────────────────
        'valvulopatia_aort':   ['diuretico', 'anti-hipertensivo', 'betabloqueant', 'cirurgia valvar', 'tavi', 'tavr'],
        'valvulopatia_mitr':   ['diuretico', 'betabloqueant', 'anticoagul', 'cirurgia valvar', 'clip mitral percutan'],
        'estenose_aortica':    ['diuretico', 'cirurgia troca valva aortica', 'tavi', 'tavr', 'evitar vasodilatad'],
        'insuf_aortica':       ['diuretico', 'vasodilatad', 'hidralazina', 'nifedipino', 'cirurgia aortica'],
        'insuf_mitral':        ['diuretico', 'ieca', 'vasodilatad', 'cirurgia reparo mitral', 'clip mitral'],
        'estenose_mitral':     ['diuretico', 'betabloqueant', 'anticoagul', 'valvuloplastia mitral'],
        'cardiopatia_congen':  ['cirurgia corretora', 'prostaglandina e1', 'alprostadil', 'indometacina pca', 'ibuprofeno pca'],
        'bloqueio_ramo':       ['marcapasso', 'monitoramento', 'tratar causa base'],
        'sindrome_qrs_longo':  ['evitar drogas qt', 'betabloqueant', 'sulfato magnesio torsades', 'marcapasso estimulacao rapida'],
        'wolf_parkinson':      ['ablacao cateter wpw', 'adenosina', 'evitar digoxina wpw'],
        'sind_brugada':        ['cdn implant', 'quinidina', 'evitar gatilhos febre'],
        'arteriopatia_perif':  ['cilostazol', 'aspirina', 'clopidogrel', 'estatina', 'anti-hipertensivo', 'ticagrelor', 'revascularizacao'],
        'aneurisma_aortico':   ['betabloqueant', 'anti-hipertensivo', 'cirurgia endovascular evar', 'cirurgia aberta'],
        'angina_microvascular':['betabloqueant', 'calcio bloqueador', 'nitrato', 'ivabradina', 'ranolazin'],
        'sind_tako_tsubo':     ['suporte hemodinamico', 'betabloqueant', 'ieca', 'aspirina', 'anticoagul transitorio'],
        'hipertensao_resist':  ['espironolactona', 'eplerenona', 'hidralazina', 'minoxidil', 'clonidina', 'denervacao renal'],
        'taquicardia_sinusal': ['betabloqueant', 'ivabradina', 'tratar causa base'],
        'extrassistolia':      ['betabloqueant', 'antiarritmico', 'ablacao cateter', 'tratar causa'],
        // ── NEFROLOGIA AVANÇADA ──────────────────────────────────────────────
        'glom_membranosa':     ['rituximab', 'ciclofosfamida', 'corticosteroid', 'ieca', 'anticoagul profilat'],
        'nefropatia_igA':      ['ieca', 'bra', 'corticosteroid', 'azatioprina', 'rituximab', 'budesonida liberac tardia', 'sparsentan'],
        'glom_focal_segm':     ['corticosteroid', 'ciclosporina', 'tacrolimus', 'rituximab', 'ieca'],
        'nefrop_diabetica':    ['ieca', 'bra', 'sglt2 inib', 'empagliflozin', 'dapagliflozin', 'finerenona'],
        'nefrite_lupica':      ['corticosteroid', 'micofenolato', 'ciclofosfamida', 'belimumab', 'voclosporin', 'anifrolumab'],
        'polirrenal':          ['tolvaptan', 'anti-hipertensivo', 'ieca', 'tratar complicac'],
        'nefrite_intersticial':['suspender medicam causador', 'corticosteroid', 'suporte renal'],
        'glomnefr_ancianca':   ['corticosteroid', 'ciclofosfamida', 'plasmaferese goodpasture', 'rituximab'],
        'nefrotox_contraste':  ['hidratacao pre', 'nacl iso profilax', 'minimizar contraste', 'n-acetilcisteina'],
        // ── DERMATOLOGIA AVANÇADA ────────────────────────────────────────────
        'acne':                ['retinoid topico', 'adapaleno', 'peroxido benzoila', 'antibiotico topico', 'clindamicina top', 'isotretinoina oral', 'doxiciclina oral', 'anticoncept oral acne'],
        'rosacea':             ['metronidazol topico', 'ivermectina topico', 'azelaic acid', 'doxiciclina', 'isotretinoina', 'laser'],
        'penfigo':             ['corticosteroid alta dose', 'rituximab', 'imunossupressor', 'micofenolato', 'azatioprina', 'dapsona'],
        'penfigoide':          ['corticosteroid topico', 'prednisona oral', 'doxiciclina', 'nicotinamida', 'rituximab', 'omalizumab'],
        'eritema_multiforme':  ['corticosteroid', 'aciclovir', 'ciclosporina', 'imunoglobulina iv', 'suporte dermatol'],
        'angioedema_heredit':  ['icatibanto', 'berinato', 'lanadelumab', 'garadacimab', 'esteroides sao ineficazes', 'inibidor c1'],
        'alopecia_areata':     ['corticosteroid topico', 'minoxidil', 'baricitinibe', 'ritlecitinibe', 'diphenciprone', 'imunossupressor'],
        'onicomicose':         ['terbinafina oral', 'itraconazol oral', 'ciclopirox verniz', 'fluconazol'],
        'tinea':               ['terbinafina topica', 'clotrimazol', 'fluconazol oral', 'cetoconazol'],
        'escabiose':           ['permetrina topica', 'ivermectina oral', 'benzil benzoato'],
        'herpes_simples':      ['aciclovir', 'valaciclovir', 'fanciclovir', 'docosanol topico'],
        'dermatite_contact':   ['corticosteroid topico', 'tacrolimus', 'anti-histamin', 'afastar alergeno'],
        'dermatite_sebor':     ['cetoconazol topico', 'ciclopirox', 'corticosteroid leve', 'zinco piritiona'],
        'liquen_plan':         ['corticosteroid topico', 'tacrolimus', 'corticosteroid sistemico', 'hidroxicloroquina'],
        'vitiligo':            ['corticosteroid topico', 'tacrolimus topico', 'ruxolitinibe topico', 'fototerapia', 'transplante melanocit'],
        'urticaria_cronica':   ['anti-histamin', 'cetirizina', 'fexofenadina', 'omalizumab', 'ciclosporina'],
        'melanoma_skin':       ['pembrolizumab', 'nivolumab', 'ipilimumab', 'vemurafenib braf', 'dabrafenib trametinibe', 'cirurgia'],
        'cec_pele':            ['cirurgia', 'cetuximab avanc', 'pembrolizumab avanc', 'radioterapia'],
        'cbc_pele':            ['cirurgia mohs', 'vismodegibe', 'sonidegibe', 'cemiplimab avanc'],
        // ── OFTALMOLOGIA ─────────────────────────────────────────────────────
        'glaucoma':            ['latanoprosta', 'travoprosta', 'bimatoprosta', 'brimonidina', 'dorzolamida', 'timolol', 'pilocarpina', 'trabeculoplastia'],
        'degeneracao_macul':   ['ranibizumab', 'aflibercept', 'bevacizumab intraoc', 'faricimab', 'anti-vegf intraoc'],
        'retinop_diabetica':   ['anti-vegf intraoc', 'ranibizumab', 'aflibercept', 'corticosteroid intraoc', 'laser fotocoagulac'],
        'uveite':              ['corticosteroid topico', 'prednisolona colirio', 'midriatic', 'metotrexato', 'adalimumab uveite'],
        'conjuntivite':        ['antibiotico colirio', 'ciprofloxacino colirio', 'anti-histamin colirio', 'lubricante colirio'],
        'ceratite':            ['antibiotico topico', 'ciprofloxacino colirio', 'aciclovir topico ocul', 'antifungico topico ocul'],
        'endoftalmite':        ['vancomicina intravitreo', 'ceftazidima intravitreo', 'corticosteroid intravitreo'],
        'oclusao_retin':       ['aspirina', 'injecao intravitreo', 'tratar causa sist'],
        // ── OTORRINOLARINGOLOGIA ──────────────────────────────────────────────
        'otite_media':         ['amoxicilina', 'amoxicilina-clavulanato', 'ceftriaxona', 'observacao sem antibiot mild'],
        'otite_externa':       ['antibiotico topico', 'ciprofloxacino colirio', 'corticosteroid topico', 'acido acetico'],
        'sinusite':            ['amoxicilina-clavulanato', 'doxiciclina', 'levofloxacino', 'nasal irrigacao', 'decongestion'],
        'faringite':           ['amoxicilina', 'penicilina v', 'cefalexina', 'azitromicina', 'observacao viral'],
        'epistaxe':            ['pressao nasal', 'nitrato prata', 'tamponamento nasal', 'acido tranexam', 'vitamina k'],
        'tontura_labirint':    ['betaistina', 'dimenidrinato', 'meclizina', 'reposicao vppb', 'corticosteroid'],
        'meniere':             ['betaistina', 'diuretico', 'dieta hiposodica', 'gentamicina intratimpanica', 'cirurgia labirinto'],
        'paralisia_facial':    ['corticosteroid', 'prednisona', 'aciclovir ramsay hunt', 'fisioterapia facial'],
        'surdez_neurossens':   ['corticosteroid', 'vasodilatad', 'vitaminas', 'aparelho auditivo'],
        // ── GINECOLOGIA E OBSTETRÍCIA ─────────────────────────────────────────
        'candidose_vaginal':   ['fluconazol oral', 'clotrimazol topico', 'miconazol vaginal', 'nistatina'],
        'vaginose_bact':       ['metronidazol oral', 'metronidazol gel vaginal', 'clindamicina vaginal', 'tinidazol'],
        'tricomonas':          ['metronidazol', 'tinidazol', 'tratar parceiro'],
        'doip':                ['ceftriaxona', 'doxiciclina', 'metronidazol', 'ofloxacino', 'clindamicina'],
        'gravidez_ectopica':   ['metotrexato', 'cirurgia urgencia', 'salpingectomia'],
        'menopausa':           ['terapia hormonal menopausa', 'estrogen', 'progesterona', 'ssri sintoma', 'gabapentina flushes', 'phytoestrogen'],
        'osteoporose_menop':   ['bisfosfonato', 'alendronato', 'zoledronato', 'denosumab', 'teriparatida', 'romosozumab', 'calcio', 'vitamina d'],
        'cancer_colo_utero':   ['cisplatina', 'carboplatina', 'bevacizumab', 'pembrolizumab', 'tisotumab vedotin'],
        'cancer_utero':        ['progestagen', 'megestrol', 'quimioterapia', 'pembrolizumab', 'lenalidomida'],
        'cancer_ovario':       ['carboplatina', 'paclitaxel', 'bevacizumab', 'olaparib', 'niraparib', 'rucaparib'],
        'hiperemes_gravid':    ['ondansetrona', 'metoclopramida', 'prometazina', 'doxilamina', 'vitamina b6', 'corticosteroid'],
        'colestase_gestac':    ['acido ursodesoxicolico', 'antipruritic', 'colestiramina'],
        'diabetes_gestac':     ['insulina', 'metformina gestac', 'controle glicemico'],
        'mastite':             ['antibiotico', 'dicloxacilina', 'cefalexina', 'clindamicina', 'ordenha continua'],
        // ── PEDIATRIA AVANÇADA ────────────────────────────────────────────────
        'sepse_neonatal':      ['ampicilina', 'gentamicina', 'cefotaxima', 'vancomicina', 'suporte intensivo'],
        'sindrome_resp_neo':   ['surfactante exogeno', 'cpap neonatal', 'corticosteroid pre natal', 'oxigenio'],
        'enterocolite_necrot': ['antibiotico', 'ampicilina', 'gentamicina', 'metronidazol', 'cirurgia necrose'],
        'hiperbilirrubin_neon':['fototerapia', 'exsanguinotransfusao', 'imunoglobulina iv'],
        'crise_febril':        ['diazepam retal', 'midazolam nasal', 'lorazepam', 'antipiret'],
        'autismo':             ['risperidona', 'aripiprazol', 'melatonina sono', 'ssri', 'terapia compor'],
        'tdah':                ['metilfenidato', 'anfetamina', 'lisdexanfetamina', 'atomoxetina', 'clonidina', 'guanfacina'],
        'sindrome_west':       ['vigabatrina', 'acth', 'corticosteroid', 'valproato', 'pirido xina'],
        'sindrome_dravet':     ['clobazam', 'valproato', 'stiripentol', 'fenfluramin', 'cannabidiol'],
        'sarampo':             ['vitamina a', 'suporte sintomatic', 'isolamento'],
        'escarlatina':         ['amoxicilina', 'penicilina', 'cefalexina', 'azitromicina'],
        // ── UROLOGIA AVANÇADA ─────────────────────────────────────────────────
        'bexiga_hiperativa':   ['oxibutinina', 'solifenacina', 'tolterodina', 'mirabegrona', 'betmiga', 'vibegron', 'toxina botulinica'],
        'cistite_intersticial':['pentosan polissulfat', 'heparina intravesic', 'alcalinizante urin', 'amitriptilina'],
        'cancer_rim':          ['sunitinibe', 'pazopanibe', 'axitinibe', 'pembrolizumab', 'nivolumab', 'cabozantinibe', 'lenvatinibe', 'bevacizumab'],
        'cancer_bexiga':          ['gem-cis', 'gemcitabina cisplatina', 'pembrolizumab', 'atezolizumab', 'erdafitinibe', 'gemcitabina', 'cisplatina'],
        'cancer_testicular':          ['bleomicina', 'etoposida', 'cisplatina', 'bep ', 'radioterapia', 'bep'],
        'orquite':             ['antibiotico', 'aine', 'suporte'],
        'epididimite':         ['ciprofloxacino', 'doxiciclina', 'ceftriaxona'],
        'incontinencia_urin':  ['kegel', 'duloxetina', 'oxibutinina', 'mirabegrona', 'pessario', 'cirurgia sling'],
        // ── PSIQUIATRIA AVANÇADA ──────────────────────────────────────────────
        'adhd_adulto':         ['metilfenidato', 'lisdexanfetamina', 'anfetamina', 'atomoxetina', 'bupropiona', 'guanfacina', 'clonidina'],
        'anorexia_nervosa':    ['olanzapina', 'ssri', 'suporte nutric', 'realimentacao', 'terapia famil'],
        'bulimia':             ['fluoxetina alta dose', 'ssri', 'tcc bulimia', 'terapia cognit'],
        'personalidade_bord':  ['dbt', 'ssri', 'quetiapina', 'lamotrigina', 'olanzapina', 'clonazepam'],
        'insonia':             ['melatonina', 'zolpidem', 'eszopiclone', 'ramelteon', 'suvorexant', 'lemborexant', 'trazodona', 'mirtazapina', 'tcc-i'],
        'hipersonia':          ['modafinil', 'armodafinil', 'oxibato sodio', 'pitolisant'],
        'narcolepsia':         ['modafinil', 'armodafinil', 'oxibato sodio', 'venlafaxina cataplexia', 'pitolisant'],
        'sindrome_pernas_inq': ['pramipexol', 'ropinirol', 'gabapentina', 'pregabalina', 'ferro reposicao', 'clonazepam'],
        'delirium_idoso':      ['haloperidol baixa dose', 'quetiapina baixa dose', 'tratar causa base', 'reorientac'],
        // ── MEDICINA INTENSIVA / TOXICOLOGIA ─────────────────────────────────
        'sdra':                ['ventilacao protetora', 'pronacao', 'cisatracurio', 'dexametasona', 'noradrenalina', 'almitrina'],
        'intox_paracetamol':   ['n-acetilcisteina', 'hemodialise graves', 'transplante hepat fulmin'],
        'intox_organofosfat':  ['atropina', 'pralidoxima', 'benzodiazep', 'suporte resp'],
        'intox_monoxido':      ['oxigenio 100%', 'camara hiperbar', 'suporte sintomatic'],
        'intox_metanol':       ['etanol iv', 'fomepizol', 'hemodialise', 'acido folico'],
        'intox_etilenoglicol': ['fomepizol', 'etanol iv', 'hemodialise', 'tiamina', 'piridoxina'],
        'intox_digoxina':      ['fragmento fab', 'digibind', 'digifab', 'atropina', 'marcapasso'],
        'intox_litio':         ['hemodialise', 'hidratacao', 'suspender litio', 'monitoramento'],
        'hipotermia':          ['reaquecimento ativo', 'fluido quente iv', 'bypass cardiopulm reaquec'],
        'hipertermia':         ['resfriamento rapido', 'benzodiazep', 'dantrolene maligna', 'suporte'],
        'mordedura':           ['soro antiofidico', 'soro botrops', 'soro crotali', 'atropina organofosf morde', 'penicilina pasteurella'],
        'hipercalcemia_maligna':['hidratacao', 'furosemida', 'bisfosfonato', 'denosumab', 'calcitonina', 'prednisona', 'cinacalcet'],
        'sind_lise_tumoral':   ['alopurinol', 'rasburicase', 'febuxostate', 'hidratacao', 'alcalinizacao urina', 'hemodialise'],
        'crise_miastenia':     ['imunoglobulina iv', 'plasmaferese', 'piridostigmina ajuste', 'corticosteroid', 'suporte resp'],
        'hipertensao_intracran':['manitol', 'nacl 3% hipert', 'drenagem ventricular', 'decubito 30 graus', 'hiperventilac transitor'],
        'embolia_gordura':      ['suporte respiratorio', 'oxigenio', 'corticosteroid'], // note: 'embolia_gordura' key in conditionKeywords
        // ── NUTRIÇÃO ─────────────────────────────────────────────────────────
        'desnutricao':         ['suporte nutric', 'nutricao enteral', 'nutricao parenteral', 'reposicao vitaminas', 'tiamina'],
        'defic_vitamina_d':    ['colecalciferol', 'vitamina d3', 'calcitriol', 'ergocalciferol'],
        'defic_vitamina_b12':  ['cianocobalamina', 'hidroxicobalamina', 'vitamina b12 im', 'b12 oral alta dose'],
        'defic_acido_folico':  ['acido folico', 'folato suplemento'],
        'defic_zinco':         ['zinco sulfato oral', 'zinco acetato', 'zinco suplemento'],
        // ── ONCOLOGIA AVANÇADA ───────────────────────────────────────────────
        'cancer_tireoide':     ['radioiodo', 'levotiroxina supressiva', 'sorafenibe', 'lenvatinibe', 'vandetanibe', 'cabozantinibe', 'selpercatinibe'],
        'cancer_rim_avancado': ['sunitinibe', 'pazopanibe', 'axitinibe', 'pembrolizumab', 'nivolumab', 'cabozantinibe', 'lenvatinibe', 'everolimus'],
        'glioblastoma':        ['temozolomida', 'bevacizumab', 'radioterapia', 'ttfields'],
        'meduloblastoma':      ['quimioterapia', 'cisplatina', 'vincristina', 'ciclofosfamida', 'radioterapia'],
        'sarcoma':             ['doxorubicina', 'ifosfamida', 'gencitabina', 'docetaxel', 'trabectedina', 'larotrectinibe'],
        'carcinoma_espinocel_cabeca_pescoco':['cetuximab', 'pembrolizumab', 'nivolumab', 'cisplatina', 'docetaxel', 'radioterapia'],
        'cistite_hemorragica': ['mesna', 'hiperhidratacao', 'acido tranexam', 'prostaglandina intravesic'],
        // ── TRANSPLANTE ──────────────────────────────────────────────────────
        'rejeicao_transplante':['tacrolimus', 'ciclosporina', 'micofenolato', 'corticosteroid', 'basiliximab', 'metilprednisolona pulsoterapia'],
        'transplante_medula':  ['ciclofosfamida', 'bussulfano', 'fludarabina', 'melfalano', 'ciclosporina', 'tacrolimus', 'metotreximo profilax gvhd'],
        'doexa_enxerto_hosped':['corticosteroid', 'ciclosporina', 'tacrolimus', 'micofenolato', 'rituximab', 'ibrutinibe', 'ruxolitinibe gvhd cronic'],
        // ── GERIATRIA ─────────────────────────────────────────────────────────
        'sindrome_fragil':     ['exercicio fisico', 'suporte nutric', 'vitamina d', 'proteina suplemento', 'revisao medicam'],
        'quedas_idoso':        ['vitamina d', 'calcio', 'fisioterapia', 'revisao medicam', 'adaptacao ambiente'],
        'depressao_idoso':     ['ssri', 'escitalopram', 'sertralina', 'venlafaxina', 'mirtazapina', 'evitar triciclico'],
        // ── FARMACOLOGIA ─────────────────────────────────────────────────────
        'dislipidemia':        ['estatina', 'atorvastatina', 'rosuvastatina', 'ezetimiba', 'fibratos', 'acido nicotinico', 'alirocumab', 'evolocumab', 'inclisiran'],
        'hipercolesterol_fam': ['alirocumab', 'evolocumab', 'inclisiran', 'ezetimiba', 'estatina alta intensid', 'lomitapida'],
        'resistencia_insul':   ['metformina', 'pioglitazona', 'semaglutida', 'liraglutida', 'sglt2 inib', 'exercicio'],
        'hiperuricemia':       ['alopurinol', 'febuxostate', 'benzbromarona', 'lesinurad', 'dieta hiperuricemia'],
        'reacao_adversa':      ['suspender medicam', 'tratar sintoma', 'anti-histamin', 'corticosteroid', 'adrenalina anafilaxia'],
        'polifarmacia':        ['revisao medicam', 'desprescricao', 'criterio beers', 'avaliacao farmacolog'],
        // ── ALERGOLOGIA ──────────────────────────────────────────────────────
        'alerg_alimentar':     ['adrenalina emergencia', 'anti-histamin', 'corticosteroid', 'imunoterapia oral alim', 'evitar alergen'],
        'alerg_penicilina':    ['carbapenem se necessario', 'macrolid', 'vancomicina', 'teste dessensibilizac'],
        'rinosinusite_alerg':  ['anti-histamin', 'furoato fluticasona nasal', 'montelucaste', 'imunoterapia alergen'],
        'asma_alerg':          ['salbutamol', 'corticosteroid inalat', 'montelucaste', 'omalizumab', 'dupilumab', 'tezepelumab'],
        'eosinofilia_alerg':   ['corticosteroid', 'mepolizumab', 'benralizumab', 'reslizumab', 'anti-il5'],
        // ── MEDICINA DO SONO ─────────────────────────────────────────────────
        'apneia_obstrutiva':   ['cpap', 'bpap', 'mandibular avanco dispositiv', 'cirurgia uvulopalato', 'perdapesoobesi'],
        // ── DOENÇAS AUTOIMUNES ────────────────────────────────────────────────
        'imunodefic_primaria': ['imunoglobulina iv reposi', 'antibiotico profilat', 'transplante celula trunc', 'terapia genica'],
        'imunodefic_comum':    ['imunoglobulina iv', 'antibiotico profilat', 'azitromicina profilat'],
        'scid':                ['transplante celula trunc', 'terapia genica', 'imunoglobulina iv'],
        // ── EMERGÊNCIAS ESPECIAIS ─────────────────────────────────────────────
        'crise_addisoniana':   ['hidrocortisona iv 100mg', 'solucao salina', 'glicose iv', 'fludrocortisona manutenc'],
        'neutropenia_grave':   ['filgrastim', 'pegfilgrastim', 'antibiotico', 'antifungico profilat', 'isolamento'],
        'hipoglicemia_grave':  ['glicose 50% iv', 'glucagon 1mg im', 'glicose 10% manut'],
        'sind_comp_abdom':     ['descompressao cirurgica', 'drenagem', 'manitol', 'suporte intensivo'],
        // ── OXIGENIO / SUPORTE ────────────────────────────────────────────────
        'oxigenoterapia':      ['mascara reservatorio', 'cateter nasal o2', 'ventilacao nao invasiva', 'bipap', 'cpap', 'ventilacao mecanica'],
        'hiperbarica':         ['oxigenio hiperbar 100%', 'sessoes oht', 'camara pressurizada'],
        // ── CARDIOMETABÓLICO ──────────────────────────────────────────────────
        'hipertriglicerid':    ['fibratos', 'fenofibrato', 'gemfibrozila', 'acido eicosapentaenoico', 'icosapent etil', 'niacina', 'omega 3'],
      };

      final relevantGroups = detectedCondition != null
          ? (conditionToGroups[detectedCondition] ?? <String>[])
          : <String>[];

      // Buscar fármacos que correspondam à condição
      final indicationDrugs = <DrugModel>[];
      for (final drug in drugsDatabase) {
        final dNorm  = _normalize(drug.name + ' ' + drug.group + ' ' + drug.getField(drug.className, _lang) + ' ' + (drug.getField(drug.mechanism, _lang)));
        // Match por grupo/classe da condição
        if (relevantGroups.any((g) => dNorm.contains(g))) {
          indicationDrugs.add(drug);
          if (indicationDrugs.length >= 8) break;
        }
        // Match direto por palavras da query nos metadados do fármaco
        if (indicationDrugs.length < 8) {
          final queryWords = qExpanded.split(RegExp(r'\s+')).where((w) => w.length > 4);
          if (queryWords.any((w) => dNorm.contains(w))) {
            if (!indicationDrugs.contains(drug)) indicationDrugs.add(drug);
          }
        }
      }

      if (indicationDrugs.isNotEmpty) {
        final buf0b = StringBuffer();
        final condLabel = detectedCondition ?? (es ? 'esta condición' : 'esta condição');
        buf0b.writeln(es
            ? '## Fármacos utilizados en $condLabel — Base interna:'
            : '## Fármacos utilizados em $condLabel — Base interna:');
        buf0b.writeln('');

        for (final drug in indicationDrugs) {
          buf0b.writeln('### ${drug.name}');
          final cls = drug.getField(drug.className, _lang);
          if (cls.isNotEmpty) buf0b.writeln('  **${es ? "Clase" : "Classe"}:** $cls');
          final fd = drug.getField(drug.fixedDose, _lang);
          if (fd.isNotEmpty) buf0b.writeln('  **${es ? "Dosis" : "Dose"}:** $fd');
          if (_patient.weight.isNotEmpty) {
            try {
              final calc = calculateDose(drug);
              buf0b.writeln('  **${es ? "Dosis calculada" : "Dose calculada"} (${_patient.weight} kg):** ${calc.main}');
            } catch (_) {}
          }
          final mech = drug.getField(drug.mechanism, _lang);
          if (mech.isNotEmpty) {
            final mechShort = mech.length > 150 ? '${mech.substring(0, 150)}...' : mech;
            buf0b.writeln('  **${es ? "Mecanismo" : "Mecanismo"}:** $mechShort');
          }
          final warn = drug.getField(drug.warning, _lang);
          if (warn.isNotEmpty) {
            final warnShort = warn.length > 120 ? '${warn.substring(0, 120)}...' : warn;
            buf0b.writeln('  **${es ? "Alerta" : "Alerta"}:** $warnShort');
          }
          final clcrVal0b = double.tryParse((clcr ?? '').replaceAll(',', '.'));
          if (clcrVal0b != null && clcrVal0b > 0 && clcrVal0b < 60) {
            final ra = drug.getField(drug.renalAlert, _lang);
            if (ra.isNotEmpty) buf0b.writeln('  ⚠ ClCr $clcr: ${ra.length > 100 ? "${ra.substring(0, 100)}..." : ra}');
          }
          buf0b.writeln('');
        }

        buf0b.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
        return buf0b.toString();
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 0 — FARMACOLOGIA DIRETA (prioridade absoluta)
    // Resposta completa sempre: classe, mecanismo, dose, via, efeitos adversos,
    // contraindicações, interações com medicamentos do paciente, ajuste renal.
    // Serve como contexto RAG estruturado para o Gemini.
    // ════════════════════════════════════════════════════════════════════════
    final isPharmaQuestion = _has(qExpanded, [
      'via de admin', 'forma de admin', 'via admin', 'como admin',
      'como dar', 'como usar', 'modo de usar', 'modo de admin', 'rota de admin',
      'dose ', 'dosagem', 'posolog', 'dose maxima', 'dose minima',
      'dose inicial', 'dose de ataque', 'dose de manutenc',
      'mecanismo', 'mecanismo de acao', 'como funciona', 'por que usar',
      'efeito adverso', 'efeito colateral', 'reacao adversa', 'toxicidade',
      'interacao', 'interacoes', 'interage', 'compativel',
      'contraindicacao', 'contraindicado', 'nao usar', 'quando nao',
      'indicacao', 'indicado para', 'para que serve', 'quando usar',
      'ajuste renal', 'atencao renal',
      // espanhol
      'via de administracion', 'como administrar', 'dosis', 'posologia',
      'mecanismo de accion', 'efecto adverso', 'efectos secundarios',
      'interaccion', 'contraindicacion', 'para que sirve', 'alerta renal',
    ]);

    if (isPharmaQuestion) {
      final matchedDrugs = _matchDrugs(_normalize(qExpanded));
      if (matchedDrugs.isNotEmpty) {
        // Detectar foco da pergunta para priorizar seções no output
        final askingVia   = _has(qExpanded, ['via ', 'via de', 'forma de admin', 'como admin', 'como dar', 'rota', 'modo de', 'administracion']);
        final askingDose  = _has(qExpanded, ['dose', 'dosagem', 'posolog', 'dosis']);
        final askingMech  = _has(qExpanded, ['mecanismo', 'como funciona', 'por que', 'mecanismo de acao', 'mecanismo de accion']);
        final askingAdv   = _has(qExpanded, ['adverso', 'colateral', 'reacao', 'toxicidad', 'efectos sec', 'efeito']);
        final askingInter = _has(qExpanded, ['interacao', 'interaccion', 'interage', 'compativel', 'junto com', 'combinar']);
        final askingCI    = _has(qExpanded, ['contraindicacao', 'contraindicado', 'nao usar', 'contraindicacion', 'nao pode', 'proibido']);
        final askingInd   = _has(qExpanded, ['indicacao', 'indicado', 'para que', 'quando usar', 'sirve', 'indicacion', 'uso']);
        // Se nenhum foco específico → mostrar tudo (ficha completa)
        final showAll = !askingVia && !askingDose && !askingMech && !askingAdv
                     && !askingInter && !askingCI && !askingInd;

        final buf = StringBuffer();
        buf.writeln(es ? '## Información farmacológica — Base interna:' : '## Informações farmacológicas — Base interna:');
        buf.writeln('');

        for (final drug in drugsDatabase) {
          final dName = _normalize(drug.name);
          final words = qExpanded.split(RegExp(r'\s+')).where((w) => w.length > 3);
          if (!words.any((w) => dName.contains(w))) continue;

          // ── Cabeçalho do fármaco ──────────────────────────────────────────
          buf.writeln('### ${drug.name}');
          final cls = drug.getField(drug.className, _lang);
          if (cls.isNotEmpty) buf.writeln('  **${es ? "Clase" : "Classe"}:** $cls');

          // ── Via de administração (sempre mostrada ou quando perguntada) ────
          if (askingVia || showAll) {
            if (drug.route.isNotEmpty) buf.writeln('  **${es ? "Vía" : "Via"}:** ${drug.route}');
          }

          // ── Dose (sempre mostrada ou quando perguntada) ────────────────────
          if (askingDose || showAll) {
            final fd = drug.getField(drug.fixedDose, _lang);
            if (fd.isNotEmpty) buf.writeln('  **${es ? "Dosis habitual" : "Dose habitual"}:** $fd');
            if (_patient.weight.isNotEmpty) {
              try {
                final calc = calculateDose(drug);
                buf.writeln('  **${es ? "Dosis calculada" : "Dose calculada"} (${_patient.weight} kg):** ${calc.main}');
                for (final a in calc.alerts.take(2)) buf.writeln('  ⚠ $a');
              } catch (_) {}
            }
          }

          // ── Mecanismo de ação (sempre mostrado ou quando perguntado) ───────
          if (askingMech || showAll) {
            final mech = drug.getField(drug.mechanism, _lang);
            if (mech.isNotEmpty) {
              final mechTrunc = mech.length > 300 ? '${mech.substring(0, 300)}...' : mech;
              buf.writeln('  **${es ? "Mecanismo de acción" : "Mecanismo de ação"}:** $mechTrunc');
            }
          }

          // ── Indicações (quando perguntado ou ficha completa) ───────────────
          if (askingInd || showAll) {
            final cls2 = drug.getField(drug.className, _lang);
            if (cls2.isNotEmpty && cls2 != cls) buf.writeln('  **${es ? "Indicaciones principales" : "Indicações principais"}:** $cls2');
          }

          // ── Efeitos adversos (sempre na ficha completa) ────────────────────
          if (askingAdv || showAll) {
            final advList = drug.getAdverse(_lang);
            if (advList.isNotEmpty) {
              buf.writeln('  **${es ? "Efectos adversos" : "Efeitos adversos"}:** ${advList.take(6).join(', ')}');
            }
          }

          // ── Contraindicações / Alertas (sempre na ficha completa) ──────────
          if (askingCI || showAll) {
            final warn = drug.getField(drug.warning, _lang);
            if (warn.isNotEmpty) {
              final warnTrunc = warn.length > 250 ? '${warn.substring(0, 250)}...' : warn;
              buf.writeln('  **${es ? "Contraindicaciones / Alertas" : "Contraindicações / Alertas"}:** $warnTrunc');
            }
          }

          // ── Interações com medicamentos do paciente ────────────────────────
          if (askingInter || showAll) {
            final interList = DrugInteractionService.checkInteractions(
              selectedDrugNames: [drug.name],
              patientMedicationsText: _patient.medications,
            );
            if (interList.isNotEmpty) {
              buf.writeln('  **${es ? "Interacciones detectadas" : "Interações detectadas (medicamentos do paciente)"}:**');
              for (final inter in interList.take(5)) {
                final sevIcon = inter.severity == InteractionSeverity.contraindicated
                    ? '⛔'
                    : inter.severity == InteractionSeverity.major
                        ? '🔴'
                        : inter.severity == InteractionSeverity.moderate
                            ? '🟠'
                            : '🟡';
                final sevLabel = inter.severity == InteractionSeverity.contraindicated
                    ? (es ? 'CONTRAINDICADO' : 'CONTRAINDICADO')
                    : inter.severity == InteractionSeverity.major
                        ? (es ? 'Mayor' : 'Maior')
                        : inter.severity == InteractionSeverity.moderate
                            ? (es ? 'Moderada' : 'Moderada')
                            : (es ? 'Menor' : 'Menor');
                final eff = inter.effect;
                final effTrunc = eff.length > 120 ? '${eff.substring(0, 120)}...' : eff;
                buf.writeln('    $sevIcon $sevLabel — ${inter.drug1} + ${inter.drug2}: $effTrunc');
              }
            } else if (askingInter) {
              buf.writeln('  ${es ? "Sin interacciones registradas con los medicamentos actuales del paciente." : "Nenhuma interação registrada com os medicamentos atuais do paciente."}');
            }
          }

          // ── Ajuste renal (sempre quando ClCr reduzido) ────────────────────
          final clcrPharma = double.tryParse((clcr ?? '').replaceAll(',', '.'));
          if (clcrPharma != null && clcrPharma > 0 && clcrPharma < 60) {
            final ra = drug.getField(drug.renalAlert, _lang);
            if (ra.isNotEmpty) {
              final raLevel = clcrPharma < 15 ? '🔴 ALERTA RENAL GRAVE' : clcrPharma < 30 ? '🟠 Alerta renal' : '🟡 Atenção renal';
              final raTrunc = ra.length > 200 ? '${ra.substring(0, 200)}...' : ra;
              buf.writeln('  **$raLevel (ClCr $clcr mL/min):** $raTrunc');
            }
          }

          // ── Alerta em idosos (se ≥75 anos) ────────────────────────────────
          final ageVal0 = int.tryParse(_patient.age);
          if (ageVal0 != null && ageVal0 >= 75) {
            final ea = drug.getField(drug.elderlyAlert, _lang);
            if (ea.isNotEmpty) buf.writeln('  **${es ? "Alerta en adulto mayor" : "Alerta em idoso"}:** $ea');
          }

          buf.writeln('');
        }

        if (buf.length > 80) {
          buf.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
          return buf.toString();
        }
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 1 — SISTEMA DE PONTUAÇÃO POR CONDIÇÃO
    //
    // Cada condição tem uma lista de keywords específicas.
    // Score = nº de keywords encontradas em q (mensagem atual).
    // Condições com score 0 são descartadas.
    // Apenas a condição de maior score é renderizada.
    // Em caso de empate, a primeira na lista de prioridade vence.
    // ════════════════════════════════════════════════════════════════════════

    // Estrutura: (id, label, protocolId, keywords, exams, redFlags)
    final conditions = <_CliCondition>[

      // ── PCR / Parada (prioridade máxima) ─────────────────────────────────
      _CliCondition(
        id: 'pcr',
        label: es ? 'Parada Cardiorrespiratoria / PCR' : 'Parada Cardiorrespiratória / PCR',
        protocolId: 'pcr_adulto',
        keywords: ['pcr', 'parada cardiac', 'sem pulso', 'fv ', 'fibrilac ventr', 'tv sem pulso', 'reanimac', 'acls'],
        exams: ['Monitor/desfibrilador', 'Glicemia pós-ROSC', 'Gasometria pós-ROSC', 'ECG pós-ROSC'],
        flags: [es ? 'ACLS inmediato: RCP + desfibrilación' : 'ACLS imediato: RCP de alta qualidade + desfibrilação',
                es ? 'Adrenalina 1 mg IV cada 3–5 min' : 'Adrenalina 1 mg IV cada 3–5 min'],
        differentials: es
            ? ['FV/TVSP (desfibrilable)', 'AESP (no desfibrilable)', 'Asistolia', 'Causas 5H5T (hipoxia, hipovolemia, hipotermia, hipo/hiperpotasemia, hidrogenión, tensión neumotórax, taponamiento, trombosis, tóxicos)']
            : ['FV/TVSP (desfibrilável)', 'AESP (não desfibrilável)', 'Assistolia', 'Causas 5H5T (hipóxia, hipovolemia, hipotermia, hipo/hipercalemia, íon H+, tensão pneumotórax, tamponamento, trombose, tóxicos)'],
        treatment: es
            ? ['1. RCP de alta calidad: 30:2, profundidad 5-6 cm, frecuencia 100-120/min', '2. Desfibrilar FV/TVSP: 200J bifásico inmediatamente', '3. Adrenalina 1 mg IV cada 3-5 min (desde el 2º ciclo en no desfibrilables)', '4. Amiodarona 300 mg IV en FV/TVSP refractaria (2ª dosis: 150 mg)', '5. Identificar y corregir causas reversibles (5H5T)', '6. Cuidados post-ROSC: normoxia, normocapnia, hipotermia terapéutica']
            : ['1. RCP de alta qualidade: 30:2, profundidade 5-6 cm, frequência 100-120/min', '2. Desfibrilar FV/TVSP: 200J bifásico imediatamente', '3. Adrenalina 1 mg IV a cada 3-5 min (a partir do 2º ciclo em não desfibriláveis)', '4. Amiodarona 300 mg IV em FV/TVSP refratária (2ª dose: 150 mg)', '5. Identificar e corrigir causas reversíveis (5H5T)', '6. Cuidados pós-ROSC: normóxia, normocapnia, hipotermia terapêutica'],
        guidelines: ['AHA ACLS 2020', 'ILCOR 2020', 'ERC 2021'],
      ),

      // ── Choque ────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'choque',
        label: es ? 'Choque (cardiogénico / séptico / hipovolémico)' : 'Choque (cardiogênico / séptico / hipovolêmico)',
        protocolId: 'choque_cardiogenico',
        keywords: ['hipotens', 'choque', 'pele fria', 'oliguria', 'lactato', 'hipoperfus', 'extremid frias', 'pam ', 'vasopressor'],
        exams: [es ? 'Lactato arterial' : 'Lactato arterial', 'Gasometria', 'ECG', es ? 'Ecocardiograma a pie de cama' : 'Ecocardiograma beira-leito'],
        flags: [es ? 'PAM <65 → vasopresor inmediato' : 'PAM <65 → vasopressor imediato',
                es ? 'Lactato >4 → reanimación 30 mL/kg' : 'Lactato >4 → reanimação agressiva 30 mL/kg'],
        differentials: es
            ? ['Choque séptico (fiebre, foco infeccioso)', 'Choque cardiogénico (IC, IAM)', 'Choque hipovolémico (hemorragia, deshidratación)', 'Choque distributivo (anafilaxia, neurológico)', 'Choque obstructivo (TEP masivo, taponamiento)']
            : ['Choque séptico (febre, foco infeccioso)', 'Choque cardiogênico (IC, IAM)', 'Choque hipovolêmico (hemorragia, desidratação)', 'Choque distributivo (anafilaxia, neurogênico)', 'Choque obstrutivo (TEP maciço, tamponamento)'],
        treatment: es
            ? ['1. Establecer acceso IV/IO y monitor contínuo', '2. Lactato >4: reanimación con SF 30 mL/kg en 3h', '3. PAM <65 refractaria a volumen: noradrenalina 0,1-3 mcg/kg/min', '4. Choque cardiogénico: dobutamina 5-20 mcg/kg/min + furosemida si congestión', '5. Choque séptico: antibiótico en <1h + hemocultivos', '6. Meta: PAM ≥65, diuresis >0,5 mL/kg/h, lactato decrescente']
            : ['1. Acesso IV/IO + monitor contínuo', '2. Lactato >4: SF 30 mL/kg em 3h', '3. PAM <65 refratária a volume: noradrenalina 0,1-3 mcg/kg/min', '4. Choque cardiogênico: dobutamina 5-20 mcg/kg/min + furosemida se congestão', '5. Choque séptico: antibiótico em <1h + hemoculturas', '6. Meta: PAM ≥65, diurese >0,5 mL/kg/h, lactato decrescente'],
        guidelines: ['Surviving Sepsis Campaign 2021', 'AHA Cardiogenic Shock 2022', 'ESICM 2023'],
      ),

      // ── IAM / SCA ─────────────────────────────────────────────────────────
      _CliCondition(
        id: 'iam',
        label: es ? 'Síndrome Coronario Agudo (IAM/Angina)' : 'Síndrome Coronariana Aguda (IAM/Angina)',
        protocolId: 'iam_congestao',
        keywords: ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', ' sca ', 'troponina', 'supradesnivel', 'sindrome coron'],
        // NOTA: ' sca ' com espaços evita falso positivo em "brusca" (bru|sca)
        exams: [es ? 'ECG seriado (0–6–12h)' : 'ECG seriado (0–6–12h)', es ? 'Troponina (0–3h)' : 'Troponina (0–3h)', 'RX tórax', es ? 'Glucemia' : 'Glicemia'],
        flags: [es ? 'Supradesnivel ST → cateterismo urgente' : 'Supradesnivelamento ST → cateterismo urgente',
                es ? 'Hipotensión → choque cardiogénico' : 'Hipotensão → choque cardiogênico'],
        differentials: es
            ? ['IAMCSST (supradesnivel ST, reperfusión urgente)', 'IAMSEST/AI (troponina + sin supra)', 'Disección aórtica (dolor desgarrador, asimetría PA)', 'Pericarditis (mejora sentado, roce)', 'TEP (disnea, hipoxia, S1Q3T3)', 'Espasmo esofágico (alivia con nitrato)']
            : ['IAMCSST (supradesnivelamento ST, reperfusão urgente)', 'IAMSEST/AI (troponina + sem supra)', 'Dissecção aórtica (dor dilacerante, assimetria PA)', 'Pericardite (melhora sentado, atrito)', 'TEP (dispneia, hipóxia, S1Q3T3)', 'Espasmo esofágico (alivia com nitrato)'],
        treatment: es
            ? ['1. IAMCSST: AAS 300 mg + clopidogrel/ticagrelor + heparina → cateterismo en <90 min', '2. IAMSEST alto riesgo: AAS 300 mg + ticagrelor 180 mg + bivalirudina → cath en <24h', '3. Morfina 2-4 mg IV si dolor intenso (con precaución — puede reducir absorción antiagregantes)', '4. Nitratos: isosorbida SL o IV si PA >100 (contraindicado en IAM de VD e hipotensión)', '5. Betabloqueantes VO en ausencia de IC aguda/bradicardia', '6. Killip II-IV: furosemida 40 mg IV + VNI si EAP']
            : ['1. IAMCSST: AAS 300 mg + clopidogrel/ticagrelor + heparina → cateterismo em <90 min', '2. IAMSEST alto risco: AAS 300 mg + ticagrelor 180 mg + bivalirudina → cath em <24h', '3. Morfina 2-4 mg IV se dor intensa (cautela — pode reduzir absorção dos antiplaquetários)', '4. Nitratos: isossorbida SL ou IV se PA >100 (contraindicado em IAM de VD e hipotensão)', '5. Betabloqueadores VO na ausência de IC aguda/bradicardia', '6. Killip II-IV: furosemida 40 mg IV + VNI se EAP'],
        guidelines: ['ESC NSTEMI 2023', 'ESC STEMI 2023', 'AHA/ACC NSTE-ACS 2021'],
      ),

      // ── TEP ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'tep',
        label: es ? 'Tromboembolismo Pulmonar (TEP)' : 'Tromboembolismo Pulmonar (TEP)',
        protocolId: 'tep_agudo',
        keywords: ['tep', 'tromboembol pulm', 'embolia pulm', 'tvp', 'wells', 'd-dimero', 'angiotc torac'],
        exams: [es ? 'D-dímero (si baja probabilidad)' : 'D-dímero (se baixa probabilidade)', es ? 'AngioTC tórax' : 'AngioTC tórax', 'ECG (S1Q3T3)', 'Troponina', 'Score de Wells'],
        flags: [es ? 'Choque/hipotensión → trombolítico sistémico urgente' : 'Choque/hipotensão → trombolítico sistêmico urgente'],
        differentials: es
            ? ['Neumonía/pleuritis (fiebre, crepitantes)', 'IAM/Angina (ECG, troponina)', 'Neumotórax (timpanismo, ausencia de MV)', 'Pericarditis aguda', 'EPOC exacerbado', 'Ansiedad/hiperventilación']
            : ['Pneumonia/pleurite (febre, crepitações)', 'IAM/Angina (ECG, troponina)', 'Pneumotórax (timpanismo, ausência MV)', 'Pericardite aguda', 'DPOC exacerbado', 'Ansiedade/hiperventilação'],
        treatment: es
            ? ['1. TEP masivo (choque): trombólisis alteplase 100 mg IV en 2h (o 0,6 mg/kg em 15 min en PCR)', '2. TEP submasivo (disfunción VD): anticoagulación enoxaparina 1 mg/kg SC c/12h o rivaroxabán 15 mg 2×/día ×21 días', '3. TEP leve: rivaroxabán 15 mg 2×/día ×21 días → 20 mg/día, o apixabán 10 mg 2×/día ×7 días → 5 mg 2×/día', '4. Contraindicación DOAC: heparina + warfarina (INR 2-3)', '5. O2 si SpO2 <94%, vasopresores si hipotensión', '6. Filtro VCI solo si anticoagulación contraindicada']
            : ['1. TEP maciço (choque): trombolítico alteplase 100 mg IV em 2h (ou 0,6 mg/kg em 15 min em PCR)', '2. TEP submaciço (disfunção VD): anticoagulação enoxaparina 1 mg/kg SC 12/12h ou rivaroxabana 15 mg 2×/dia ×21 dias', '3. TEP leve: rivaroxabana 15 mg 2×/dia ×21 dias → 20 mg/dia, ou apixabana 10 mg 2×/dia ×7 dias → 5 mg 2×/dia', '4. Contraindicação DOAC: heparina + warfarina (INR 2-3)', '5. O2 se SpO2 <94%, vasopressores se hipotensão', '6. Filtro de VCI só se anticoagulação contraindicada'],
        guidelines: ['ESC TEP 2019', 'ACCP VTE 2021', 'AHA PE 2023'],
      ),

      // ── FA / Flutter ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'fa',
        label: es ? 'Fibrilación Auricular / Flutter' : 'Fibrilação Atrial / Flutter Atrial',
        protocolId: 'fa_aguda',
        keywords: ['fa ', 'fibrilac atrial', 'fibril atri', 'auricular', 'rr irregular', 'flutter', 'fibrilacao', 'cardioversao', 'anticoag'],
        exams: [es ? 'ECG 12 derivaciones' : 'ECG 12 derivações', 'TSH', es ? 'Electrolitos (K+, Mg2+)' : 'Eletrólitos (K+, Mg2+)', 'Ecocardiograma', es ? 'Score CHA₂DS₂-VASc' : 'Score CHA₂DS₂-VASc'],
        flags: [es ? 'FC >150 + inestabilidad → cardioversión eléctrica inmediata' : 'FC >150 + instabilidade → cardioversão elétrica imediata',
                es ? 'FA >48h sin anticoagulación → riesgo de AVC' : 'FA >48h sem anticoagulação → risco de AVC por trombo'],
        differentials: es
            ? ['Flutter auricular (ondas F en dientes de sierra, conducción 2:1/3:1)', 'TSV (QRS estrecho regular)', 'TV (QRS ancho, no responde a maniobras vagales)', 'WPW (FA preexcitada: PELIGRO con digoxina/verapamilo)']
            : ['Flutter atrial (ondas F em dentes de serra, condução 2:1/3:1)', 'TSV (QRS estreito regular)', 'TV (QRS largo, não responde a manobras vagais)', 'WPW (FA pré-excitada: PERIGO com digoxina/verapamil)'],
        treatment: es
            ? ['1. Inestable (hipotensión/síncope/EAP): cardioversión eléctrica sincronizada 120-200J', '2. Estable con FC >110: control de FC — metoprolol 2,5-5 mg IV o diltiazem 0,25 mg/kg IV', '3. FA <48h: cardioversión farmacológica — amiodarona 150 mg IV en 10 min → 1 mg/min 6h', '4. FA >48h o desconocida: anticoagular 3 semanas ANTES de cardiovertir (o ETE para descartar trombo)', '5. Anticoagulación crónica: CHA₂DS₂-VASc ≥2 (♂) o ≥3 (♀) → DOAC (rivaroxabán/apixabán/dabigatrán)', '6. Control de FC crónica: betabloqueante (metoprolol/carvedilol) o diltiazem']
            : ['1. Instável (hipotensão/síncope/EAP): cardioversão elétrica sincronizada 120-200J', '2. Estável com FC >110: controle da FC — metoprolol 2,5-5 mg IV ou diltiazem 0,25 mg/kg IV', '3. FA <48h: cardioversão farmacológica — amiodarona 150 mg IV em 10 min → 1 mg/min 6h', '4. FA >48h ou desconhecida: anticoagular 3 semanas ANTES de cardioverter (ou ETE para excluir trombo)', '5. Anticoagulação crônica: CHA₂DS₂-VASc ≥2 (♂) ou ≥3 (♀) → DOAC (rivaroxabana/apixabana/dabigatrana)', '6. Controle da FC crônica: betabloqueador (metoprolol/carvedilol) ou diltiazem'],
        guidelines: ['ESC FA 2020', 'AHA/ACC/HRS Afib 2023', 'SBC FA 2022'],
      ),

      // ── IC / EAP ──────────────────────────────────────────────────────────
      _CliCondition(
        id: 'ic',
        label: es ? 'Insuficiencia Cardíaca Descompensada / EAP' : 'Insuficiência Cardíaca Descompensada / EAP',
        protocolId: 'iam_congestao',
        keywords: ['ic ', 'insuf cardiac', 'ortopneia', 'edema pulm', 'crepitac', 'bnp', 'fej', 'frac ejec', 'congest', 'crepit', 'b3 ', 'killip'],
        exams: ['BNP/NT-proBNP', 'RX tórax', 'Ecocardiograma', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'SpO2 <90% → VNI (CPAP/BIPAP) inmediata' : 'SpO2 <90% + esforço respiratório → VNI (CPAP/BIPAP) imediata',
                es ? 'Hipotensión + IC → choque cardiogénico' : 'Hipotensão + IC → choque cardiogênico: cuidado com diurético'],
        differentials: es
            ? ['EPOC exacerbado (historia de tabaquismo, sibilancias)', 'TEP (D-dímero, angioTC)', 'Neumonía (fiebre, infiltrado asimétrico)', 'Crisis hipertensiva (PA muy elevada sin congestión previa)', 'Taponamiento cardíaco (JVD, ruidos apagados, hipotensión)']
            : ['DPOC exacerbado (tabagismo, sibilos)', 'TEP (D-dímero, angioTC)', 'Pneumonia (febre, infiltrado assimétrico)', 'Crise hipertensiva (PA muito elevada sem congestão prévia)', 'Tamponamento cardíaco (TJV, bulhas abafadas, hipotensão)'],
        treatment: es
            ? ['1. Posición sentada + O2 para SpO2 ≥94%', '2. SpO2 <90%: VNI (CPAP 5-10 cmH2O) inmediata — reduz intubación 50%', '3. Furosemida 40-80 mg IV (doble dosis si usuario crónico)', '4. Nitratos IV si PAS >110 (isosorbida 1-10 mg/h) — contraindicados si PAS <100', '5. IC con FEr baja: IECA/ARA II + betabloqueante + espironolactona + SGLT2i (mantenimiento)', '6. Hipotensión + IC: dobutamina 5-20 mcg/kg/min, evitar diuréticos agresivos']
            : ['1. Posição sentada + O2 para SpO2 ≥94%', '2. SpO2 <90%: VNI (CPAP 5-10 cmH2O) imediata — reduz intubação 50%', '3. Furosemida 40-80 mg IV (dose dupla se usuário crônico)', '4. Nitratos IV se PAS >110 (isossorbida 1-10 mg/h) — contraindicados se PAS <100', '5. ICFEr: IECA/BRA + betabloqueador + espironolactona + SGLT2i (manutenção)', '6. Hipotensão + IC: dobutamina 5-20 mcg/kg/min, evitar diurético agressivo'],
        guidelines: ['ESC IC 2021', 'AHA/ACC HF 2022', 'SBC IC 2023'],
      ),

      // ── Dissecção Aórtica ─────────────────────────────────────────────────
      _CliCondition(
        id: 'dissecc',
        label: es ? 'Disección Aórtica Aguda' : 'Dissecção Aórtica Aguda',
        protocolId: 'crise_hipertensiva',
        keywords: ['dissecc', 'dissecao aort', 'dor torn', 'interescap', 'assimetr', 'diseccion aort'],
        exams: [es ? 'AngioTC aorta urgente' : 'AngioTC aorta urgente', 'RX tórax', 'ECG', es ? 'PA en ambos brazos' : 'PA nos 2 braços'],
        flags: [es ? 'NO anticoagular sin confirmar diagnóstico' : 'NÃO anticoagular sem confirmar diagnóstico',
                es ? 'Control FC+PA: meta PAS <120 + FC <60' : 'Controle FC+PA imediato: meta PAS <120 + FC <60'],
        differentials: es
            ? ['IAM (ECG + troponina, pero disección puede cursarlo como IAM)', 'TEP masivo', 'Pericarditis/derrame pericárdico', 'Estenosis aórtica grave', 'Dolor músculo-esquelético intercostal']
            : ['IAM (ECG + troponina, mas dissecção pode mimetizar IAM)', 'TEP maciço', 'Pericardite/derrame pericárdico', 'Estenose aórtica grave', 'Dor musculoesquelética intercostal'],
        treatment: es
            ? ['1. AngioTC aorta URGENTE — confirmar diagnóstico antes de cualquier intervención', '2. Tipo A (aorta ascendente): cirugía de emergencia inmediata', '3. Tipo B (aorta descendente sin complicaciones): tratamiento médico — labetalol 20 mg IV + nitroprusiato', '4. Meta FC <60 lpm + PAS <120 mmHg: esmolol 0,5 mg/kg IV → infusión 50-200 mcg/kg/min', '5. CONTRAINDICADO: anticoagulación sin confirmación de diagnóstico', '6. CUIDADO: en IAM con supra + disección → NO fibrinolítico']
            : ['1. AngioTC aorta URGENTE — confirmar diagnóstico antes de qualquer intervenção', '2. Tipo A (aorta ascendente): cirurgia de emergência imediata', '3. Tipo B (aorta descendente sem complicações): tratamento médico — labetalol 20 mg IV + nitroprussiato', '4. Meta FC <60 bpm + PAS <120 mmHg: esmolol 0,5 mg/kg IV → infusão 50-200 mcg/kg/min', '5. CONTRAINDICADO: anticoagulação sem confirmação diagnóstica', '6. CUIDADO: em IAM com supra + dissecção → NÃO fibrinolítico'],
        guidelines: ['ESC Aorta 2014', 'AHA/ACC Aorta 2022', 'SBH Aorta 2023'],
      ),

      // ── TPSV / Taquiarritmia ──────────────────────────────────────────────
      _CliCondition(
        id: 'tpsv',
        label: es ? 'Taquiarritmia Supraventricular (TPSV)' : 'Taquiarritmia Supraventricular (TPSV)',
        protocolId: 'tpsv',
        keywords: ['tpsv', 'qrs estrei', 'arritm supravent', 'palpit', 'taquic supravent'],
        exams: [es ? 'ECG 12 derivaciones' : 'ECG 12 derivações', es ? 'Electrolitos (K+, Mg2+)' : 'Eletrólitos (K+, Mg2+)', 'TSH'],
        flags: [es ? 'Inestabilidad hemodinámica → cardioversión eléctrica' : 'Instabilidade hemodinâmica → cardioversão elétrica',
                es ? 'Estable con QRS estrecho → maniobras vagales → adenosina' : 'Estável QRS estreito → manobras vagais → adenosina'],
        differentials: es
            ? ['FA/Flutter (RR irregular)', 'Taquicardia sinusal (causa secundaria: deshidratación, anemia, infección)', 'TV (QRS ancho ≥0,12s — más peligrosa)', 'WPW (δ wave en ritmo sinusal)', 'Taquicardia por reentrada nodal (TRNAV): pausa post-adenosina diagnóstica']
            : ['FA/Flutter (RR irregular)', 'Taquicardia sinusal (causa secundária: desidratação, anemia, infecção)', 'TV (QRS largo ≥0,12s — mais perigosa)', 'WPW (δ wave no ritmo sinusal)', 'Taquicardia por reentrada nodal (TRNAV): pausa pós-adenosina diagnóstica'],
        treatment: es
            ? ['1. Inestable (síncope/hipotensión/EAP): cardioversión eléctrica sincronizada 50-100J', '2. Estable QRS estrecho: maniobra de Valsalva modificada (más efectiva: 40 mmHg 15s + decúbito)', '3. Sin respuesta a vagal: adenosina 6 mg IV rápido (+ flush 20 mL SF) → si no: 12 mg → 12 mg', '4. FA preexcitada (WPW): CONTRAINDICADO adenosina/verapamilo/diltiazem/digoxina → procainamida', '5. Metoprolol 2,5-5 mg IV lento si no responde a adenosina y QRS estrecho', '6. Para prevención: ablación por catéter (curación >95% en TRNAV)']
            : ['1. Instável (síncope/hipotensão/EAP): cardioversão elétrica sincronizada 50-100J', '2. Estável QRS estreito: manobra de Valsalva modificada (mais eficaz: 40 mmHg 15s + decúbito)', '3. Sem resposta à vagal: adenosina 6 mg IV rápido (+ flush 20 mL SF) → se não: 12 mg → 12 mg', '4. FA pré-excitada (WPW): CONTRAINDICADO adenosina/verapamil/diltiazem/digoxina → procainamida', '5. Metoprolol 2,5-5 mg IV lento se sem resposta à adenosina e QRS estreito', '6. Para prevenção: ablação por cateter (cura >95% em TRNAV)'],
        guidelines: ['ESC SVT 2019', 'AHA/ACC SVT 2015', 'ACC SVT 2016'],
      ),

      // ── AVC ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'avc',
        label: es ? 'ACV (Isquémico / Hemorrágico)' : 'AVC (Isquêmico / Hemorrágico)',
        protocolId: 'avc_isquemico',
        keywords: ['avc', 'acidente vasc', 'hemiplegi', 'deficit focal', 'afasia', 'hemiparesia', 'desvio boca', 'nihss', 'tpa ', 'alteplase', 'acv ', 'ave '],
        exams: [es ? 'TC cráneo URGENTE (sin contraste)' : 'TC crânio URGENTE (sem contraste)', es ? 'Glucemia capilar' : 'Glicemia capilar', es ? 'Coagulación' : 'Coagulação', 'ECG', 'PA'],
        flags: [es ? 'Ventana trombolítica: <4,5h' : 'Janela trombolítica: <4,5h',
                es ? 'Hipoglucemia mimetiza AVC — siempre checar glucemia' : 'Hipoglicemia mimetiza AVC — checar glicemia sempre',
                es ? 'HTA grave: tratar solo si PAS >220 (sin trombolítico)' : 'HTA grave: tratar só se PAS >220 (sem trombolítico)'],
        differentials: es
            ? ['ACV hemorrágico (TC sin contraste urgente antes de trombolítico)', 'Hipoglucemia (SIEMPRE descartar — mimetiza AVC)', 'Parálisis de Todd (postictal)', 'Encefalopatía hipertensiva', 'Tumor cerebral con déficit agudo', 'Crisis focal epiléptica']
            : ['AVC hemorrágico (TC sem contraste urgente antes do trombolítico)', 'Hipoglicemia (SEMPRE excluir — mimetiza AVC)', 'Paralisia de Todd (pós-ictal)', 'Encefalopatia hipertensiva', 'Tumor cerebral com déficit agudo', 'Crise focal epiléptica'],
        treatment: es
            ? ['1. TC cráneo URGENTE sin contraste (descartar hemorragia)', '2. Glicemia capilar IMEDIATA — corregir si <60 o >180 mg/dL', '3. ACV isquémico + <4,5h + sin CI: alteplase 0,9 mg/kg IV (máx 90 mg, 10% en bolo + 90% en 60 min)', '4. Contraindicaciones tPA: hemorragia en TC, cirugía reciente, INR >1,7, plaquetas <100k', '5. NIHSS ≥6 + oclusión proximal: trombectomía mecánica hasta 24h (seleccionar por imagen)', '6. PA: no tratar si <220/120 (sin trombolítico) — si tPA: meta PA <180/105 durante 24h']
            : ['1. TC crânio URGENTE sem contraste (excluir hemorragia)', '2. Glicemia capilar IMEDIATA — corrigir se <60 ou >180 mg/dL', '3. AVC isquêmico + <4,5h + sem CI: alteplase 0,9 mg/kg IV (máx 90 mg, 10% em bolo + 90% em 60 min)', '4. Contraindicações tPA: hemorragia no TC, cirurgia recente, INR >1,7, plaquetas <100k', '5. NIHSS ≥6 + oclusão proximal: trombectomia mecânica até 24h (selecionar por imagem)', '6. PA: não tratar se <220/120 (sem trombolítico) — se tPA: meta PA <180/105 por 24h'],
        guidelines: ['AHA/ASA Stroke 2019', 'ESC Stroke 2021', 'SBC/SBN AVC 2022'],
      ),

      // ── Hemorragia Intracraniana ───────────────────────────────────────────
      _CliCondition(
        id: 'hic',
        label: es ? 'Hemorragia Intracraneal' : 'Hemorragia Intracraniana',
        protocolId: 'avc_hemorragico',
        keywords: ['hemorrag intracran', 'hemorrag cerebr', 'sangr cerebr', 'hematoma subdur', 'hematoma extradur', 'hsa', 'hic '],
        exams: [es ? 'TC cráneo urgente' : 'TC crânio urgente', es ? 'Coagulación completa' : 'Coagulação completa', 'Plaquetas'],
        flags: [es ? 'CONTRAINDICADO trombolítico y anticoagulantes' : 'CONTRAINDICADO trombolítico e anticoagulantes',
                es ? 'Revertir anticoagulación inmediatamente' : 'Reverter anticoagulação imediatamente'],
        differentials: es
            ? ['HSA (punción lumbar si TC negativa — xantocromía)', 'Hematoma epidural (intervalo lúcido + trauma)', 'Hematoma subdural agudo/crónico', 'HIC espontánea (HTA, angiopatía amiloide, malformación vascular)', 'Transformación hemorrágica de ACV isquémico']
            : ['HSA (punção lombar se TC negativa — xantocromia)', 'Hematoma epidural (intervalo lúcido + trauma)', 'Hematoma subdural agudo/crônico', 'HIC espontânea (HAS, angiopatia amiloide, malformação vascular)', 'Transformação hemorrágica de AVC isquêmico'],
        treatment: es
            ? ['1. CONTRAINDICADOS: tPA, anticoagulantes, AAS', '2. Revertir anticoagulación INMEDIATA: Warfarina → Vit K 10 mg IV + CCP 4F; DOAC → idarucizumab/andexanet', '3. PA: meta PAS 130-150 mmHg (labetalol o nicardipino IV)', '4. Manejo PIC: cabecera 30°, evitar hipotónicas, considerar manitol 0,5-1 g/kg', '5. Convulsiones: LEV 1 g IV (no profilaxis rutinaria)', '6. HSA: nimodipino 60 mg VO c/4h por 21 días (vasoespasmo), clipaje/espiral urgente']
            : ['1. CONTRAINDICADOS: tPA, anticoagulantes, AAS', '2. Reverter anticoagulação IMEDIATA: Varfarina → Vit K 10 mg IV + CCP 4F; DOAC → idarucizumabe/andexanete', '3. PA: meta PAS 130-150 mmHg (labetalol ou nicardipino IV)', '4. Manejo PIC: cabeceira 30°, evitar hipotônicas, considerar manitol 0,5-1 g/kg', '5. Convulsões: LEV 1 g IV (sem profilaxia rotineira)', '6. HSA: nimodipino 60 mg VO 4/4h por 21 dias (vasoespasmo), clipagem/espiral urgente'],
        guidelines: ['AHA/ASA ICH 2022', 'ESC Stroke 2021', 'Neurocrit Care Society 2022'],
      ),

      // ── Status Epilepticus ────────────────────────────────────────────────
      _CliCondition(
        id: 'epilepsia',
        label: es ? 'Status Epiléptico / Convulsión' : 'Status Epilepticus / Convulsão',
        protocolId: 'status_epilepticus',
        keywords: ['convuls', 'epileps', 'status epilep', 'crise convuls', 'crise epilep', 'benzodiaz', 'diazepam', 'midazolam', 'lorazepam'],
        exams: [es ? 'Glucemia' : 'Glicemia', es ? 'Electrolitos (Na+, Mg2+, Ca2+)' : 'Eletrólitos (Na+, Mg2+, Ca2+)', es ? 'TC cráneo' : 'TC crânio', 'EEG se status refratário'],
        flags: [es ? 'Crisis >5 min → benzodiacepina INMEDIATA' : 'Crise >5 min → benzodiazepínico IMEDIATO',
                es ? 'Status refractario → midazolam/propofol en UTI' : 'Status refratário → midazolam/propofol em UTI'],
        differentials: es
            ? ['Hipoglucemia (tratar antes de BZD)', 'AVC/hemorragia (TC urgente)', 'Meningitis/encefalitis (fiebre + rigidez)', 'Intoxicación/abstinencia (opioides, BZD, alcohol)', 'Trastorno metabólico (Na+, Ca2+, uremia)', 'Crisis psicógena no epiléptica (PNES — movimientos asincrónicos)']
            : ['Hipoglicemia (tratar antes do BZD)', 'AVC/hemorragia (TC urgente)', 'Meningite/encefalite (febre + rigidez)', 'Intoxicação/abstinência (opioides, BZD, álcool)', 'Distúrbio metabólico (Na+, Ca2+, uremia)', 'Crise psicogênica não epiléptica (PNES — movimentos assíncronos)'],
        treatment: es
            ? ['1. 0-5 min: posición lateral, O2, glucemia capilar, acceso IV', '2. 5-20 min: lorazepam 0,1 mg/kg IV (máx 4 mg) o diazepam 10 mg IV o midazolam 10 mg IM', '3. 20-40 min (status establecido): fenitoína 20 mg/kg IV a 50 mg/min o LEV 60 mg/kg IV (máx 4,5 g) o valproato 40 mg/kg IV', '4. 40-60 min (status refractario): intubación + midazolam infusión 0,1-2 mg/kg/h o propofol 2-12 mg/kg/h', '5. >60 min (status superrefractario): ketamina, fenobarbital, anestesia general', '6. Investigar y corregir causa subyacente (glucemia, electrolitos, infección)']
            : ['1. 0-5 min: decúbito lateral, O2, glicemia capilar, acesso IV', '2. 5-20 min: lorazepam 0,1 mg/kg IV (máx 4 mg) ou diazepam 10 mg IV ou midazolam 10 mg IM', '3. 20-40 min (status estabelecido): fenitoína 20 mg/kg IV a 50 mg/min ou LEV 60 mg/kg IV (máx 4,5 g) ou valproato 40 mg/kg IV', '4. 40-60 min (status refratário): intubação + midazolam infusão 0,1-2 mg/kg/h ou propofol 2-12 mg/kg/h', '5. >60 min (status super-refratário): cetamina, fenobarbital, anestesia geral', '6. Investigar e corrigir causa subjacente (glicemia, eletrólitos, infecção)'],
        guidelines: ['Neurocrit Care 2023', 'EAN Status 2022', 'SBN Status 2021'],
      ),

      // ── Meningite / Encefalite ────────────────────────────────────────────
      _CliCondition(
        id: 'meningite',
        label: es ? 'Meningitis / Encefalitis Bacteriana' : 'Meningite / Encefalite Bacteriana',
        protocolId: 'sepse',
        keywords: ['meningite', 'encefalite', 'rigidez nuca', 'kernig', 'brudzinski', 'petequi', 'nucal', 'rigidez de nuca'],
        exams: [es ? 'TC cráneo (antes de la PL si focal)' : 'TC crânio (antes da PL se focal)', es ? 'Punción lumbar' : 'Punção lombar', es ? 'Hemocultivos' : 'Hemoculturas', es ? 'Glucemia' : 'Glicemia', 'PCR'],
        flags: [es ? 'ATB INMEDIATO — no demorar por PL' : 'ATB IMEDIATO — não atrasar por PL',
                es ? 'Dexametasona 0,15 mg/kg IV antes o junto al ATB' : 'Dexametasona 0,15 mg/kg IV antes ou junto ao ATB'],
        differentials: es
            ? ['Encefalitis viral herpética (HSV — aciclovir empírico)', 'HSA (TC + PL: xantocromía)', 'Absceso cerebral (fiebre + déficit focal + efecto de masa)', 'Meningitis criptocócica (inmunodeprimido)', 'Meningitis tuberculosa (curso subagudo, LCR con linfocitos)']
            : ['Encefalite viral herpética (HSV — aciclovir empírico)', 'HSA (TC + PL: xantocromia)', 'Abscesso cerebral (febre + déficit focal + efeito de massa)', 'Meningite criptocócica (imunodeprimido)', 'Meningite tuberculosa (curso subagudo, LCR com linfócitos)'],
        treatment: es
            ? ['1. ATB EMPÍRICO INMEDIATO (no demorar por punción): ceftriaxona 2 g IV c/12h', '2. Dexametasona 0,15 mg/kg IV c/6h ×4 días — iniciar ANTES o junto al ATB (reduce mortalidad en bacteriana)', '3. <50 años inmunocompetente: ceftriaxona + vancomicina 15-20 mg/kg IV c/8h', '4. >50 años o inmunosuprimido: + ampicilina 2 g IV c/4h (cobertura Listeria)', '5. HSV sospechado (encefalitis): aciclovir 10 mg/kg IV c/8h', '6. PL solo después de TC negativo para efecto de masa (si hay signos focales)']
            : ['1. ATB EMPÍRICO IMEDIATO (não atrasar por punção): ceftriaxona 2 g IV 12/12h', '2. Dexametasona 0,15 mg/kg IV 6/6h ×4 dias — iniciar ANTES ou junto ao ATB (reduz mortalidade na bacteriana)', '3. <50 anos imunocompetente: ceftriaxona + vancomicina 15-20 mg/kg IV 8/8h', '4. >50 anos ou imunossuprimido: + ampicilina 2 g IV 4/4h (cobertura Listeria)', '5. HSV suspeito (encefalite): aciclovir 10 mg/kg IV 8/8h', '6. PL apenas após TC negativo para efeito de massa (se sinais focais)'],
        guidelines: ['IDSA Meningitis 2017', 'ESC Neuroinfection 2016', 'SBI Meningite 2021'],
      ),

      // ── Sepse ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'sepse',
        label: es ? 'Sepsis / Choque Séptico' : 'Sepse / Choque Séptico',
        protocolId: 'sepse',
        keywords: ['sepse', 'seps', 'septic', 'bacterem', 'infec grave', 'choque septic', 'sofa', 'qsofa', 'bundle'],
        exams: ['Lactato', es ? 'Hemocultivos (2 pares)' : 'Hemoculturas (2 pares)', es ? 'Urocultivos' : 'Urocultura', 'PCR/Procalcitonina', es ? 'Función renal' : 'Função renal', 'Gasometria'],
        flags: [es ? 'Antibiótico en <1 HORA' : 'Antibiótico em <1 HORA',
                es ? 'Lactato >4 → 30 mL/kg SF' : 'Lactato >4 → 30 mL/kg SF',
                es ? 'Vasopresor si PAM <65 tras volumen' : 'Vasopressor se PAM <65 após volume'],
        differentials: es
            ? ['Choque cardiogénico (BNP, ecocardiograma)', 'Anafilaxia (exposición alergénica, urticaria)', 'Choque hemorrágico (buscar foco de sangrado)', 'Insuficiencia suprarrenal aguda (hipotensión refractaria)', 'Intoxicación grave (toxicológico)']
            : ['Choque cardiogênico (BNP, ecocardiograma)', 'Anafilaxia (exposição alergênica, urticária)', 'Choque hemorrágico (buscar foco de sangramento)', 'Insuficiência suprarrenal aguda (hipotensão refratária)', 'Intoxicação grave (toxicológico)'],
        treatment: es
            ? ['1. Hemocultivos (2 pares) + urocultivo ANTES del ATB (sin demorar)', '2. ATB en <1h: foco desconocido → piperacilina-tazobactam 4,5 g IV c/6h o meropenem 1 g c/8h', '3. Lactato >2: reanimación SF 30 mL/kg en 3h; lactato >4: UCI urgente', '4. PAM <65 refractaria: noradrenalina 0,1-3 mcg/kg/min (primera línea)', '5. Corticoides solo en choque séptico refractario: hidrocortisona 200 mg/día IV', '6. Controlar foco: drenaje quirúrgico/IR si absceso/empiema/peritonitis; retirar catéter infectado']
            : ['1. Hemoculturas (2 pares) + urocultura ANTES do ATB (sem atrasar)', '2. ATB em <1h: foco desconhecido → piperacilina-tazobactam 4,5 g IV 6/6h ou meropeném 1 g 8/8h', '3. Lactato >2: reanimação SF 30 mL/kg em 3h; lactato >4: UTI urgente', '4. PAM <65 refratária: noradrenalina 0,1-3 mcg/kg/min (primeira linha)', '5. Corticoides apenas em choque séptico refratário: hidrocortisona 200 mg/dia IV', '6. Controlar foco: drenagem cirúrgica/IR se abscesso/empiema/peritonite; retirar cateter infectado'],
        guidelines: ['Surviving Sepsis Campaign 2021', 'ESICM 2023', 'SBI Sepse 2020'],
      ),

      // ── DPOC ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'dpoc',
        label: es ? 'EPOC en Exacerbación Aguda' : 'DPOC em Exacerbação Aguda',
        protocolId: 'dpoc_exacerbacao',
        keywords: ['dpoc', 'doenca pulm obstr', 'enfisema', 'bronquite cronica', 'exacerbac pulm', 'epoc', 'paco2', 'hipercapn'],
        exams: ['Gasometria arterial', 'RX tórax', 'SpO2', 'Hemograma', 'PCR'],
        flags: [es ? 'O2 CONTROLADO: SpO2 objetivo 88–92%' : 'O2 CONTROLADO: SpO2 alvo 88–92%',
                es ? 'pH <7,35 + PaCO2 elevado → VNI inmediata' : 'pH <7,35 + PaCO2 elevado → VNI imediata'],
        differentials: es
            ? ['Neumonía (fiebre, infiltrado RX, esputo purulento)', 'Neumotórax (timpanismo, ausencia MV, RX)', 'IC descompensada (ortopnea, edemas, BNP)', 'TEP (hipoxia + disnea aguda + D-dímero)', 'Broncoespasmo por AINE/betabloqueante']
            : ['Pneumonia (febre, infiltrado RX, escarro purulento)', 'Pneumotórax (timpanismo, ausência MV, RX)', 'IC descompensada (ortopneia, edemas, BNP)', 'TEP (hipóxia + dispneia aguda + D-dímero)', 'Broncoespasmo por AINE/betabloqueador'],
        treatment: es
            ? ['1. O2 CONTROLADO: Venturi 24-28% → meta SpO2 88-92% (riesgo de retención CO2 con O2 alto)', '2. Broncodilatadores nebulizados: salbutamol 2,5 mg + ipratropio 0,5 mg cada 20 min × 3, luego c/4h', '3. Corticoides sistémicos: prednisona 40 mg VO 5 días (o prednisolona 0,5 mg/kg/día)', '4. ATB si: esputo purulento + aumento disnea: amoxicilina-clavulanato 875/125 mg c/12h ×5-7d o azitromicina', '5. pH <7,35 + PaCO2 >45 + FR >25: VNI (BIPAP): IPAP 10-20, EPAP 4-8 cmH2O', '6. Falla VNI/apneas/Glasgow ≤8: intubación orotraqueal']
            : ['1. O2 CONTROLADO: Venturi 24-28% → meta SpO2 88-92% (risco de retenção CO2 com O2 alto)', '2. Broncodilatadores nebulizados: salbutamol 2,5 mg + ipratrópio 0,5 mg a cada 20 min × 3, depois 4/4h', '3. Corticoides sistêmicos: prednisona 40 mg VO 5 dias (ou prednisolona 0,5 mg/kg/dia)', '4. ATB se: escarro purulento + aumento dispneia: amoxicilina-clavulanato 875/125 mg 12/12h ×5-7d ou azitromicina', '5. pH <7,35 + PaCO2 >45 + FR >25: VNI (BIPAP): IPAP 10-20, EPAP 4-8 cmH2O', '6. Falha VNI/apneias/Glasgow ≤8: intubação orotraqueal'],
        guidelines: ['GOLD 2024', 'NICE COPD 2023', 'SBPT DPOC 2022'],
      ),

      // ── Asma ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'asma',
        label: es ? 'Asma en Crisis / Broncoespasmo' : 'Asma em Crise / Broncoespasmo Agudo',
        protocolId: 'asma_grave',
        keywords: ['asma', 'broncoespas', 'sibilo', 'wheezing', 'peak flow', 'pfe ', 'broncodilatad'],
        exams: ['SpO2', es ? 'PFE (peak flow)' : 'PFE (peak flow)', es ? 'Gasometría si grave' : 'Gasometria se grave', es ? 'RX tórax si duda' : 'RX tórax se dúvida'],
        flags: [es ? 'Silencio auscultatorio + SpO2 <90% → riesgo de PCR inminente' : 'Silêncio auscultório + SpO2 <90% → risco de PCR iminente'],
        differentials: es
            ? ['EPOC exacerbado (fumador, hipercapnia)', 'Neumotórax (dolor pleurítico, asimetría MV)', 'Cuerpo extraño en vía aérea (inicio súbito, sin historia de asma)', 'Anafilaxia (urticaria, angioedema, hipotensión)', 'Insuficiencia cardíaca (ortopnea, BNP)']
            : ['DPOC exacerbado (tabagismo, hipercapnia)', 'Pneumotórax (dor pleurítica, assimetria MV)', 'Corpo estranho nas vias aéreas (início súbito, sem história de asma)', 'Anafilaxia (urticária, angioedema, hipotensão)', 'Insuficiência cardíaca (ortopneia, BNP)'],
        treatment: es
            ? ['1. O2 para SpO2 ≥92% (≥95% en embarazo)', '2. SABA nebulizado: salbutamol 2,5-5 mg c/20 min × 3 (o MDI 4-8 puffs c/20 min)', '3. Ipratropio 0,5 mg nebulizado junto con salbutamol en moderada/grave (primeras 3h)', '4. Corticoides IV: hidrocortisona 100-200 mg c/6h o metilprednisolona 1 mg/kg/día', '5. MgSO4 2 g IV en 20 min: en crisis grave con SpO2 <92% sin respuesta a SABA', '6. Silencio auscultatorio + hipercapnia + fatiga: intubación (Ket 1-2 mg/kg para inducción)']
            : ['1. O2 para SpO2 ≥92% (≥95% na gestação)', '2. SABA nebulizado: salbutamol 2,5-5 mg a cada 20 min × 3 (ou MDI 4-8 puffs a cada 20 min)', '3. Ipratrópio 0,5 mg nebulizado junto ao salbutamol em moderada/grave (primeiras 3h)', '4. Corticoides IV: hidrocortisona 100-200 mg 6/6h ou metilprednisolona 1 mg/kg/dia', '5. MgSO4 2 g IV em 20 min: em crise grave com SpO2 <92% sem resposta ao SABA', '6. Silêncio auscultório + hipercapnia + fadiga: intubação (Ket 1-2 mg/kg para indução)'],
        guidelines: ['GINA 2024', 'BTS/SIGN 2023', 'SBPT Asma 2020'],
      ),

      // ── CAD ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'cad',
        label: es ? 'Cetoacidosis Diabética (CAD)' : 'Cetoacidose Diabética (CAD)',
        protocolId: 'cad_shh',
        keywords: ['cetoacid', 'cad', 'hiperglicemi', 'cetona', 'acidose metabol', 'dka', 'ph baixo+diabet'],
        exams: [es ? 'Glucemia' : 'Glicemia', es ? 'Cetonemia/cetonuria' : 'Cetonemia/cetonúria', es ? 'Gasometría venosa' : 'Gasometria venosa', es ? 'Electrolitos (K+ urgente)' : 'Eletrólitos (K+ urgente)', 'BUN/Cr'],
        flags: [es ? 'K+ <3,3 → SUSPENDER insulina y reponer K+ primero' : 'K+ <3,3 → SUSPENDER insulina e repor K+ primeiro'],
        differentials: es
            ? ['Estado Hiperosmolar Hiperglucémico (EHH): glucemia >600, osmolaridad >320, sin cetonuria', 'Acidosis láctica (lactato, no cetonuria)', 'Cetosis alcohólica (glucemia normal/baja, alcohol)', 'Acidosis metabólica por intoxicación (salicilatos, metanol)', 'Pancreatitis aguda (lipasa, imagen)']
            : ['Estado Hiperosmolar Hiperglicêmico (EHH): glicemia >600, osmolaridade >320, sem cetonúria', 'Acidose lática (lactato, sem cetonúria)', 'Cetose alcoólica (glicemia normal/baixa, álcool)', 'Acidose metabólica por intoxicação (salicilatos, metanol)', 'Pancreatite aguda (lipase, imagem)'],
        treatment: es
            ? ['1. Hidratación: SF 0,9% 1 L/h × 2h → 0,5 L/h según PVC/diuresis', '2. K+ >3,3 y <5,5: insulina regular 0,1 U/kg bolus → 0,1 U/kg/h; K+ <3,3: SUSPENDER insulina, reponer KCl 40 mEq/h primero', '3. Meta: reducir glucemia 50-70 mg/dL/h; cuando <200 → añadir SG5%', '4. K+ cada 2h: meta 4-5 mEq/L (la insulina baja K+ — riesgo fatal)', '5. Bicarbonato solo si pH <6,9 (100 mEq en 2h)', '6. Buscar causa: infección, abandono insulina, IAM, pancreatitis — tratar causa']
            : ['1. Hidratação: SF 0,9% 1 L/h × 2h → 0,5 L/h conforme PVC/diurese', '2. K+ >3,3 e <5,5: insulina regular 0,1 U/kg bolus → 0,1 U/kg/h; K+ <3,3: SUSPENDER insulina, repor KCl 40 mEq/h primeiro', '3. Meta: reduzir glicemia 50-70 mg/dL/h; quando <200 → adicionar SG5%', '4. K+ a cada 2h: meta 4-5 mEq/L (insulina baixa K+ — risco fatal)', '5. Bicarbonato apenas se pH <6,9 (100 mEq em 2h)', '6. Buscar causa: infecção, abandono insulina, IAM, pancreatite — tratar causa'],
        guidelines: ['ADA DKA 2023', 'ISPAD DKA 2022', 'SBD 2023'],
      ),

      // ── Hipoglicemia ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipoglicemia',
        label: es ? 'Hipoglucemia Grave' : 'Hipoglicemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipoglicemi', 'glicemia bai', 'hipoglucemi', 'glicose baixa'],
        exams: [es ? 'Glucemia capilar URGENTE' : 'Glicemia capilar URGENTE', es ? 'Glucemia venosa' : 'Glicemia venosa'],
        flags: [es ? 'Glucemia <60 → 50 mL glucosa 50% IV inmediato' : 'Glicemia <60 → 50 mL glicose 50% IV imediato',
                es ? 'Sin acceso IV → glucagón 1 mg IM/SC' : 'Sem acesso IV → glucagon 1 mg IM/SC'],
        differentials: es
            ? ['Hipoglucemia por insulina/sulfonilureas (más frecuente)', 'Insulinoma (hipoglucemia de ayuno, péptido C elevado)', 'Insuficiencia suprarrenal (hipotensión, hiponatremia)', 'Hipoglucemia alcohólica (gluconeogénesis inhibida)', 'Causa iatrogénica (error de dosis, ayuno inadecuado)']
            : ['Hipoglicemia por insulina/sulfonilureias (mais frequente)', 'Insulinoma (hipoglicemia de jejum, peptídeo C elevado)', 'Insuficiência suprarrenal (hipotensão, hiponatremia)', 'Hipoglicemia alcoólica (gliconeogênese inibida)', 'Causa iatrogênica (erro de dose, jejum inadequado)'],
        treatment: es
            ? ['1. Glucemia <70 consciente: 15-20 g carbohidrato VO (sucrose, jugo); repetir si <70 en 15 min', '2. Glucemia <50 o inconsciente: glucosa 50% 50 mL IV rápido (SOS: glucagón 1 mg IM/SC)', '3. Glicemia post-tratamiento ≥100: alimentación con carbohidrato complejo + proteína', '4. Sulfonilurea/insulina de acción larga: observación mínima 12-24h (riesgo de recurrencia)', '5. Buscar causa: dosis excesiva, aumento ejercicio, disminución ingesta, IRC (ajuste dosis)', '6. Educación: hipoglucemia asintomática → riesgo de no reconocimiento → ajustar umbral terapéutico']
            : ['1. Glicemia <70 consciente: 15-20 g carboidrato VO (sacarose, suco); repetir se <70 em 15 min', '2. Glicemia <50 ou inconsciente: glicose 50% 50 mL IV rápido (SOS: glucagon 1 mg IM/SC)', '3. Glicemia pós-tratamento ≥100: alimentação com carboidrato complexo + proteína', '4. Sulfonilureia/insulina de ação longa: observação mínima 12-24h (risco de recorrência)', '5. Buscar causa: dose excessiva, aumento exercício, diminuição ingestão, IRC (ajuste dose)', '6. Educação: hipoglicemia assintomática → risco de não reconhecimento → ajustar limiar terapêutico'],
        guidelines: ['ADA Hypoglycemia 2023', 'Endocrine Society 2019', 'SBD 2023'],
      ),

      // ── Hipercalemia ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipercalemia',
        label: es ? 'Hipercalemia Grave' : 'Hipercalemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipercalemi', 'hiperpotass', 'k alt', 'hiperkalem', 'onda t apic', 'k+ elev'],
        exams: [es ? 'K+ sérico urgente' : 'K+ sérico urgente', 'ECG', 'Gasometria', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'K+ >6,5 o cambios ECG → Gluconato Ca2+ IV inmediato' : 'K+ >6,5 ou alteração ECG → Gluconato Ca2+ IV imediato',
                es ? 'Insulina + glucosa + bicarbonato + diálisis si refractario' : 'Insulina + glicose + bicarbonato + diálise se refratório'],
        differentials: es
            ? ['Pseudohiperpotasemia (hemólisis en muestra)', 'IRA/IRC descompensada', 'Hipoaldosteronismo (Addison)', 'Rabdomiólisis', 'Acidosis metabólica severa (redistribución)']
            : ['Pseudo-hipercalemia (hemólise da amostra)', 'IRA/IRC descompensada', 'Hipoaldosteronismo (Addison)', 'Rabdomiólise', 'Acidose metabólica grave (redistribuição)'],
        treatment: es
            ? ['1. ECG alterado (onda T apiculada, ensanchamiento QRS, onda sinusoidal): gluconato Ca2+ 10% 10 mL IV en 2-3 min (estabiliza membrana)', '2. Redistribución intacelular: insulina regular 10 U IV + glucosa 50% 50 mL IV (baja K+ 0,5-1 mEq/L en 30 min)', '3. Bicarbonato: NaHCO3 50 mEq IV si pH <7,2 (distribución intracelular)', '4. Eliminación: furosemida 40-80 mg IV si función renal conservada; kayexalato 15-30 g VO si IRC', '5. K+ >7 refractario o cambios ECG graves → diálisis de emergencia', '6. Suspender fármacos que elevan K+: IECA/ARA II, espirolactona, AINEs, heparina']
            : ['1. ECG alterado (onda T apiculada, alargamento QRS, onda sinusoidal): gluconato de Ca2+ 10% 10 mL IV em 2-3 min (estabiliza membrana)', '2. Redistribuição intracelular: insulina regular 10 U IV + glicose 50% 50 mL IV (baixa K+ 0,5-1 mEq/L em 30 min)', '3. Bicarbonato: NaHCO3 50 mEq IV se pH <7,2 (distribuição intracelular)', '4. Eliminação: furosemida 40-80 mg IV se função renal conservada; kayexalato 15-30 g VO se IRC', '5. K+ >7 refratário ou alterações ECG graves → diálise de emergência', '6. Suspender fármacos que elevam K+: IECA/BRA, espironolactona, AINEs, heparina'],
        guidelines: ['KDIGO AKI 2022', 'ESC Electrolytes 2019', 'ASN 2021'],
      ),

      // ── Hipopotassemia ────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipocalemia',
        label: es ? 'Hipopotasemia Grave' : 'Hipopotassemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipocalemi', 'hipopotass', 'k bai', 'hipokalem', 'k+ baixo'],
        exams: [es ? 'K+ sérico' : 'K+ sérico', es ? 'ECG (ondas U, QT largo)' : 'ECG (ondas U, QT longo)', 'Mg2+', 'Gasometria'],
        flags: [es ? 'K+ <2,5 o cambios ECG → reposición IV monitorizada' : 'K+ <2,5 ou alteração de ECG → reposição IV monitorada'],
        differentials: es
            ? ['Pérdidas gastrointestinales (vómitos, diarrea, fístulas)', 'Pérdidas renales (diuréticos, hiperaldosteronismo)', 'Redistribución (insulina, alcalosis, beta-agonistas)', 'Hipomagnesemia (siempre corregir Mg2+ en hipopotasemia refractaria)', 'CAD en tratamiento (insulina baja K+)']
            : ['Perdas gastrointestinais (vômitos, diarreia, fístulas)', 'Perdas renais (diuréticos, hiperaldosteronismo)', 'Redistribuição (insulina, alcalose, beta-agonistas)', 'Hipomagnesemia (sempre corrigir Mg2+ em hipopotassemia refratária)', 'CAD em tratamento (insulina baixa K+)'],
        treatment: es
            ? ['1. K+ 3,0-3,5: potasio VO 40-60 mEq/día (cloruro de potasio)', '2. K+ 2,5-3,0: KCl oral 80-120 mEq/día o IV 10-20 mEq/h (max 40 mEq/h en vía central con monitoreo)', '3. K+ <2,5 o síntomas (debilidad, ECG alterado): KCl IV 20-40 mEq/h en vía central + monitoreo contínuo', '4. SIEMPRE verificar y corregir Mg2+ (hipomagnesemia impide la corrección del K+)', '5. Identificar causa: alcalosis → tratar; diuréticos → reducir dosis; diarrea → tratar', '6. K+ no sube con reposición: pensar en síndrome de Bartter/Gitelman']
            : ['1. K+ 3,0-3,5: potássio VO 40-60 mEq/dia (cloreto de potássio)', '2. K+ 2,5-3,0: KCl oral 80-120 mEq/dia ou IV 10-20 mEq/h (máx 40 mEq/h em via central com monitoração)', '3. K+ <2,5 ou sintomas (fraqueza, ECG alterado): KCl IV 20-40 mEq/h em via central + monitoração contínua', '4. SEMPRE verificar e corrigir Mg2+ (hipomagnesemia impede a correção do K+)', '5. Identificar causa: alcalose → tratar; diuréticos → reduzir dose; diarreia → tratar', '6. K+ não sobe com reposição: pensar em síndrome de Bartter/Gitelman'],
        guidelines: ['ASN Electrolytes 2021', 'AHA 2019', 'SBN 2022'],
      ),

      // ── IRA ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'ira',
        label: es ? 'Insuficiencia Renal Aguda (IRA)' : 'Insuficiência Renal Aguda (IRA)',
        protocolId: 'cad_shh',
        keywords: ['insuf renal aguda', 'ira ', 'oliguria', 'anuria', 'creatinina elev', 'uremia', 'aki'],
        exams: [es ? 'Creatinina/Urea seriadas' : 'Creatinina/Ureia seriadas', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Eco renal' : 'Eco renal', 'EAS/urocultura'],
        flags: [es ? 'K+ >6 u oliguria refractaria → diálisis de urgencia' : 'K+ >6 ou oligúria refratária → diálise de urgência',
                es ? 'Descartar prerrenal (volumen) y obstructivo (eco)' : 'Excluir pré-renal (volume) e obstrutivo (eco)'],
        differentials: es
            ? ['Prerrenal (deshidratación, hipotensión, IC): fracción de Na excreción <1%', 'Intrínseca: NTA isquémica/tóxica (AINE, aminoglucósidos, contraste), glomerulonefritis, vasculitis', 'Postrenal: obstrucción (próstata, tumor, litiasis) — eco urgente']
            : ['Pré-renal (desidratação, hipotensão, IC): fração de excreção de Na <1%', 'Intrínseca: NTA isquêmica/tóxica (AINE, aminoglicosídeos, contraste), glomerulonefrite, vasculite', 'Pós-renal: obstrução (próstata, tumor, litíase) — eco urgente'],
        treatment: es
            ? ['1. Prerrenal: hidratación SF 500 mL en 30 min, evaluar respuesta (diuresis >0,5 mL/kg/h)', '2. Suspender nefrotóxicos: AINE, aminoglucósidos, contraste, IECA/ARA II, metformina', '3. Postrenal: sondaje vesical urgente o nefrostomía percutánea', '4. Monitorizar K+, pH: hipercalemia >6 → gluconato Ca2+, insulina/glucosa, diálisis', '5. Diálisis urgente: K+ >6,5 refractario, acidosis pH <7,1, uremia sintomática, sobrecarga hídrica', '6. Ajustar TODAS las dosis de fármacos según ClCr (ver sección farmacológica)']
            : ['1. Pré-renal: hidratação SF 500 mL em 30 min, avaliar resposta (diurese >0,5 mL/kg/h)', '2. Suspender nefrotóxicos: AINE, aminoglicosídeos, contraste, IECA/BRA, metformina', '3. Pós-renal: sondagem vesical urgente ou nefrostomia percutânea', '4. Monitorar K+, pH: hipercalemia >6 → gluconato Ca2+, insulina/glicose, diálise', '5. Diálise urgente: K+ >6,5 refratário, acidose pH <7,1, uremia sintomática, sobrecarga hídrica', '6. Ajustar TODAS as doses de fármacos conforme ClCr (ver seção farmacológica)'],
        guidelines: ['KDIGO AKI 2012 (updated 2023)', 'ERA-EDTA 2023', 'SBN 2022'],
      ),

      // ── HDA ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'hda',
        label: es ? 'Hemorragia Digestiva Alta (HDA)' : 'Hemorragia Digestiva Alta (HDA)',
        protocolId: 'hda_varizeal',
        keywords: ['hematemes', 'hemorrag digest', 'melena', 'hamatoquezia', 'hematoquezia', 'sangr gi', 'ulcera sangr', 'varizes esof'],
        exams: [es ? 'Hemograma (Hb, Ht)' : 'Hemograma (Hb, Ht)', es ? 'Coagulación' : 'Coagulação', es ? 'Tipaje sanguíneo' : 'Tipagem sanguínea', es ? 'Función renal' : 'Função renal', es ? 'EDA urgente' : 'EDA urgente'],
        flags: [es ? 'PA <100 + FC >100 → 2 accesos calibrosos + SF inmediato' : 'PA <100 + FC >100 → 2 acessos calibrosos + SF imediato',
                es ? 'Hb objetivo 7–8 g/dL (transfusión restrictiva)' : 'Hb alvo 7–8 g/dL (transfusão restritiva)',
                es ? 'Cirrosis + HDA → octreótido + ATB + Terlipresina' : 'Cirrose + HDA → octreotida + ATB profilático + Terlipressina'],
        differentials: es
            ? ['Úlcera péptica (H. pylori, AINE — más frecuente)', 'Varices esofágicas (cirrosis, hepatopatía)', 'Síndrome de Mallory-Weiss (vómitos repetidos)', 'Lesión de Dieulafoy (sangrado arterial puntual)', 'Cáncer gástrico/esofágico (hemorragia crónica)', 'Hemobilia o fístula aorto-entérica (raro, grave)']
            : ['Úlcera péptica (H. pylori, AINE — mais frequente)', 'Varizes esofágicas (cirrose, hepatopatia)', 'Síndrome de Mallory-Weiss (vômitos repetidos)', 'Lesão de Dieulafoy (sangramento arterial pontual)', 'Câncer gástrico/esofágico (hemorragia crônica)', 'Hemobilia ou fístula aorto-entérica (raro, grave)'],
        treatment: es
            ? ['1. Acceso IV ×2 calibrosos + SF 1 L si PA <100/FC >100 + transfundir si Hb <7 (meta 7-9 g/dL)', '2. IBP IV: omeprazol 80 mg bolus → 8 mg/h infusión (antes de EDA)', '3. No cirrosis: EDA urgente en <12h (alta urgencia) o <24h (sin inestabilidad)', '4. Cirrosis/varices: terlipresina 2 mg IV c/4-6h + ceftriaxona 1 g/día (ATB profiláctico 5-7d)', '5. Score Glasgow-Blatchford ≥12 → EDA en <6h; Rockford C/D → ligadura variceal + octreótido', '6. Refractario: TIPS (shunt intrahepático) o cirugía de urgencia']
            : ['1. Acesso IV ×2 calibrosos + SF 1 L se PA <100/FC >100 + transfundir se Hb <7 (meta 7-9 g/dL)', '2. IBP IV: omeprazol 80 mg bolus → 8 mg/h infusão (antes da EDA)', '3. Sem cirrose: EDA urgente em <12h (alta urgência) ou <24h (sem instabilidade)', '4. Cirrose/varizes: terlipressina 2 mg IV 4/4h-6/6h + ceftriaxona 1 g/dia (ATB profilático 5-7d)', '5. Score Glasgow-Blatchford ≥12 → EDA em <6h; Rockford C/D → ligadura varicosa + octreotida', '6. Refratário: TIPS (shunt intra-hepático) ou cirurgia de urgência'],
        guidelines: ['BSG HDA 2021', 'ESGE 2021', 'SBH HDA 2022'],
      ),

      // ── Abdome Agudo ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'abdome',
        label: es ? 'Abdomen Agudo / Peritonitis' : 'Abdome Agudo / Peritonite',
        protocolId: 'sepse',
        keywords: ['dor abdom', 'abdome agudo', 'peritonite', 'rigidez abd', 'defesa abdom', 'apendicite', 'colecistite', 'obstru intestinal', 'peritonitis'],
        exams: [es ? 'RX abdomen de pie' : 'RX abdome em pé', es ? 'TC abdomen+pelvis con contraste' : 'TC abdome+pelve com contraste', 'Hemograma', 'PCR', 'Lipase/amilase'],
        flags: [es ? 'Signos peritoneales + inestabilidad → cirugía de emergencia' : 'Sinais peritoneais + instabilidade → cirurgia de emergência',
                es ? 'Neumoperitoneo en RX → perforación visceral: cirugía inmediata' : 'Pneumoperitônio no RX → perfuração visceral: cirurgia imediata'],
        differentials: es
            ? ['Apendicitis aguda (fosa ilíaca derecha, Murphy de McBurney)', 'Colecistitis aguda (hipocondrio derecho, Murphy positivo, fiebre)', 'Pancreatitis aguda (epigastrio irradiado a dorso, lipasa >3×)', 'Perforación de víscera hueca (neumoperitoneo, defensa total)', 'Obstrucción intestinal (distensión, ausencia de gases distales)', 'Isquemia mesentérica (dolor intenso, leucocitosis, acidosis, lactato)']
            : ['Apendicite aguda (fossa ilíaca direita, sinal de McBurney)', 'Colecistite aguda (hipocôndrio direito, Murphy positivo, febre)', 'Pancreatite aguda (epigástrio irradiado ao dorso, lipase >3×)', 'Perfuração de víscera oca (pneumoperitônio, defesa total)', 'Obstrução intestinal (distensão, ausência de gases distais)', 'Isquemia mesentérica (dor intensa, leucocitose, acidose, lactato)'],
        treatment: es
            ? ['1. Estabilización: 2 accesos IV, SF 1-2 L, analgesia IV (ketorolac 30 mg o tramadol 100 mg)', '2. Ayuno + SNG si vómitos o distensión importante', '3. ATB empírico si sospecha infección: piperacilina-tazobactam 4,5 g IV c/6h o ampicilina + metronidazol', '4. TC abdomen+pelvis con contraste IV (estudio diagnóstico principal)', '5. Peritonitis/perforación/isquemia: cirugía de emergencia inmediata', '6. Apendicitis confirmada: apendicectomía laparoscópica; colecistitis: colecistectomía en 24-72h']
            : ['1. Estabilização: 2 acessos IV, SF 1-2 L, analgesia IV (cetorrolaco 30 mg ou tramadol 100 mg)', '2. Jejum + SNG se vômitos ou distensão importante', '3. ATB empírico se suspeita infecção: piperacilina-tazobactam 4,5 g IV 6/6h ou ampicilina + metronidazol', '4. TC abdome+pelve com contraste IV (principal exame diagnóstico)', '5. Peritonite/perfuração/isquemia: cirurgia de emergência imediata', '6. Apendicite confirmada: apendicectomia laparoscópica; colecistite: colecistectomia em 24-72h'],
        guidelines: ['WSES Peritonitis 2020', 'SAGES 2023', 'SBC Abdome 2021'],
      ),

      // ── Pancreatite ───────────────────────────────────────────────────────
      _CliCondition(
        id: 'pancreatite',
        label: es ? 'Pancreatitis Aguda' : 'Pancreatite Aguda',
        protocolId: 'sepse',
        keywords: ['pancreatite', 'pancreat', 'dor epigast irrad dorso', 'lipase elev', 'amilase elev', 'bisap', 'balthazar'],
        exams: [es ? 'Lipasa (>3× LSN)' : 'Lipase (>3× LSN diagnóstico)', es ? 'TC abdomen (Balthazar/CTSI)' : 'TC abdome (Balthazar/CTSI)', es ? 'Electrolitos' : 'Eletrólitos', 'Score BISAP'],
        flags: [es ? 'Score BISAP ≥3 → UTI (pancreatitis grave)' : 'Score BISAP ≥3 ou APACHE II alto → UTI',
                es ? 'Necroinfeción: fiebre + empeoramiento → TC + ATB' : 'Necroinfeção: febre + piora clínica → TC + ATB'],
        differentials: es
            ? ['Úlcera péptica perforada (neumoperitoneo, RX)', 'IAM inferior (ECG)', 'Colecistitis aguda (Murphy, eco)', 'Isquemia mesentérica (lactato, dolor + leucocitosis)', 'Obstrucción intestinal alta']
            : ['Úlcera péptica perfurada (pneumoperitônio, RX)', 'IAM inferior (ECG)', 'Colecistite aguda (Murphy, eco)', 'Isquemia mesentérica (lactato, dor + leucocitose)', 'Obstrução intestinal alta'],
        treatment: es
            ? ['1. Hidratación agresiva: Ringer lactato 250-500 mL/h (preferido sobre SF) primeras 24h (BISAP <3)', '2. Analgesia: ketorolac 30 mg IV o morfina 2-4 mg IV (sin evidencia de empeorar pancreatitis)', '3. Nutrición: enteral precoz en <24-48h si tolera; parenteral solo si enteral imposible', '4. BISAP ≥3/necrosante: UTI, monitoreo contínuo, anticipar complicaciones', '5. ATB solo si necroinfeción confirmada (guiada por aspiración con aguja fina TC-guiada): meropenem o imipenem', '6. Colangiopancreatografía (CPRE) urgente en <24h si: cálculo biliar + ictericia + colangitis']
            : ['1. Hidratação agressiva: Ringer lactato 250-500 mL/h (preferido ao SF) primeiras 24h (BISAP <3)', '2. Analgesia: cetorrolaco 30 mg IV ou morfina 2-4 mg IV (sem evidência de piorar pancreatite)', '3. Nutrição: enteral precoce em <24-48h se tolera; parenteral apenas se enteral impossível', '4. BISAP ≥3/necrosante: UTI, monitoramento contínuo, antecipar complicações', '5. ATB apenas em necroinfeção confirmada (guiada por aspiração com agulha fina TC-guiada): meropeném ou imipeném', '6. CPRE urgente em <24h se: cálculo biliar + icterícia + colangite'],
        guidelines: ['AGA Pancreatitis 2018', 'IAP/APA 2015', 'SBH Pancreatite 2021'],
      ),

      // ── Crise Hipertensiva ────────────────────────────────────────────────
      _CliCondition(
        id: 'crise_hipert',
        label: es ? 'Crisis Hipertensiva (Urgencia / Emergencia)' : 'Crise Hipertensiva (Urgência / Emergência)',
        protocolId: 'crise_hipertensiva',
        keywords: ['crise hipert', 'pa muito alta', 'pa >180', 'emergencia hiperten', 'encefalopatia hiperten', 'urgencia hiperten', 'hipertensao grave', 'pa > 180', 'pa 220', 'pa 200'],
        exams: [es ? 'PA en ambos brazos' : 'PA em ambos os braços', 'ECG', es ? 'Fondo de ojo' : 'Fundo de olho', es ? 'Creatinina/urea' : 'Creatinina/ureia', es ? 'TC cráneo si síntomas neurológicos' : 'TC crânio se sintomas neurológicos'],
        flags: [es ? 'Encefalopatía + PA >180 → emergencia: reducción IV controlada' : 'Encefalopatia + PA >180 → emergência: redução IV controlada',
                es ? 'NO reducir PA >25% en 1ª hora' : 'NÃO reduzir PA >25% na 1ª hora'],
        differentials: es
            ? ['Emergencia hipertensiva (lesión órgano diana: encefalopatía, IC aguda, disección, eclampsia)', 'Urgencia hipertensiva (PA muy elevada SIN lesión aguda de órgano)', 'HTA por dolor/ansiedad (tratar la causa)', 'Hipertensión de bata blanca (monitorización ambulatoria)', 'Crisis adrenérgica (feocromocitoma, cocaína — PA muy lábil)']
            : ['Emergência hipertensiva (lesão órgão-alvo: encefalopatia, IC aguda, dissecção, eclâmpsia)', 'Urgência hipertensiva (PA muito elevada SEM lesão aguda de órgão)', 'HAS por dor/ansiedade (tratar a causa)', 'HAS do avental branco (monitorização ambulatorial)', 'Crise adrenérgica (feocromocitoma, cocaína — PA muito lábil)'],
        treatment: es
            ? ['1. Emergencia (lesión diana): reducción PA controlada IV — meta: bajar 20-25% en 1ª hora, NO normalizar', '2. ACV isquémico: solo tratar si PAS >220/120 (sin trombolítico) o >180/105 (con trombolítico)', '3. Encefalopatía/IC aguda/disección: labetalol 20 mg IV → 40-80 mg c/10 min o nitroprusiato 0,25-10 mcg/kg/min', '4. Urgencia (sin lesión diana): antihipertensivo VO — captopril 25-50 mg o amlodipino 5-10 mg', '5. PA >220/120 asintomática: captopril SL + observación 30-60 min → alta si responde', '6. Ajustar medicación habitual + seguimiento en 24-72h']
            : ['1. Emergência (lesão de órgão-alvo): redução PA controlada IV — meta: baixar 20-25% em 1ª hora, NÃO normalizar', '2. AVC isquêmico: apenas tratar se PAS >220/120 (sem trombolítico) ou >180/105 (com trombolítico)', '3. Encefalopatia/IC aguda/dissecção: labetalol 20 mg IV → 40-80 mg a cada 10 min ou nitroprussiato 0,25-10 mcg/kg/min', '4. Urgência (sem lesão de órgão): anti-hipertensivo VO — captopril 25-50 mg ou anlodipino 5-10 mg', '5. PA >220/120 assintomática: captopril SL + observação 30-60 min → alta se responde', '6. Ajustar medicação habitual + seguimento em 24-72h'],
        guidelines: ['ESC/ESH Hipertensão 2023', 'AHA/ACC HTN 2022', 'SBC HAS 2020'],
      ),

      // ── Delirium ──────────────────────────────────────────────────────────
      _CliCondition(
        id: 'delirium',
        label: es ? 'Delirium / Alteración de Consciencia' : 'Delirium / Rebaixamento de Consciência',
        protocolId: 'status_epilepticus',
        keywords: ['delirium', 'confusao aguda', 'agitac', 'rebaixamento conscien', 'glasgow baixo', 'confusao mental', 'cam ', 'alterac conscien'],
        exams: [es ? 'Glucemia capilar URGENTE' : 'Glicemia capilar URGENTE', es ? 'TC cráneo' : 'TC crânio', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Función renal y hepática' : 'Função renal e hepática', 'Gasometria'],
        flags: [es ? 'Excluir SIEMPRE: hipoglucemia, AVC, meningitis, IRA, intoxicación' : 'Excluir SEMPRE: hipoglicemia, AVC, meningite, IRA, intoxicação',
                es ? 'Glasgow ≤8 → proteger vía aérea (IOT)' : 'Glasgow ≤8 → proteger via aérea (IOT)'],
        differentials: es
            ? ['Hipoglucemia (SIEMPRE primera en excluir)', 'AVC agudo (TC urgente)', 'Meningitis/encefalitis (rigidez, fiebre, LCR)', 'Encefalopatía urémica/hepática (creatinina, amoniaco)', 'Intoxicación/síndrome serotoninérgico/anticolinérgico', 'Delirium hipoactivo (agitación mínima — frecuentemente subdiagnosticado en UTI)']
            : ['Hipoglicemia (SEMPRE primeira a excluir)', 'AVC agudo (TC urgente)', 'Meningite/encefalite (rigidez, febre, LCR)', 'Encefalopatia urêmica/hepática (creatinina, amoniaco)', 'Intoxicação/síndrome serotoninérgico/anticolinérgico', 'Delirium hipoativo (agitação mínima — frequentemente subdiagnosticado em UTI)'],
        treatment: es
            ? ['1. Glucemia capilar INMEDIATA (corregir si <60 o >400)', '2. Oxigenación: SpO2 ≥94%; si Glasgow ≤8 → IOT', '3. Búsqueda sistemática de causa: TC, PL, electrolitos, función renal/hepática, toxicológico', '4. Medidas no farmacológicas: reorientación, iluminación diurna, movilización, familia, ciclo sueño-vigilia', '5. Agitación que pone en riesgo: haloperidol 2-5 mg IV (preferir IM en agitación grave) — en QT prolongado: quetiapina', '6. Evitar BZD en delirium no alcohólico (empeoran delirium en ancianos)']
            : ['1. Glicemia capilar IMEDIATA (corrigir se <60 ou >400)', '2. Oxigenação: SpO2 ≥94%; se Glasgow ≤8 → IOT', '3. Busca sistemática de causa: TC, PL, eletrólitos, função renal/hepática, toxicológico', '4. Medidas não farmacológicas: reorientação, iluminação diurna, mobilização, família, ciclo sono-vigília', '5. Agitação que coloca em risco: haloperidol 2-5 mg IV (preferir IM em agitação grave) — em QT longo: quetiapina', '6. Evitar BZD em delirium não alcoólico (pioram delirium em idosos)'],
        guidelines: ['SCCM PADIS 2018', 'APA Delirium 2023', 'ESICM Delirium 2022'],
      ),

      // ── Intoxicação ───────────────────────────────────────────────────────
      _CliCondition(
        id: 'intoxicacao',
        label: es ? 'Intoxicación Exógena / Sobredosis' : 'Intoxicação Exógena / Overdose',
        protocolId: 'pcr_adulto',
        keywords: ['intoxicac', 'overdose', 'envenenam', 'organofosf', 'naloxona', 'flumazenil', 'carvao ativ', 'toxicolog'],
        exams: [es ? 'Toxicológico urinario' : 'Toxicológico urinário', 'Gasometria', es ? 'Electrolitos' : 'Eletrólitos', es ? 'ECG (QT largo)' : 'ECG (QT longo)', es ? 'Glucemia' : 'Glicemia'],
        flags: [es ? 'Contactar Centro de Toxicología (0800 722 6001)' : 'Contato: Centro de Informação Toxicológica (0800 722 6001)',
                es ? 'Antídotos: naloxona (opioides), flumazenil (BZD), N-acetilcisteína (paracetamol)' : 'Antídotos: naloxona (opioides), flumazenil (BZD), N-acetilcisteína (paracetamol)',
                es ? 'Carbón activado 1 g/kg VO si <1h de ingesta' : 'Carvão ativado 1 g/kg VO se <1h da ingestão'],
        differentials: es
            ? ['Identificar toxidrome: anticolinérgico (midriasis, taquicardia, retención urinaria), colinérgico/organofosf (miosis, broncosecreción, bradicardia), opioide (miosis, bradipnea, depresión SNC), simpaticomimético (midriasis, taquicardia, HTA), serotoninérgico (agitación, hiperreflexia, clonus)']
            : ['Identificar toxidrome: anticolinérgico (midríase, taquicardia, retenção urinária), colinérgico/organofosf (miose, broncossecreção, bradicardia), opioide (miose, bradipneia, depressão SNC), simpatomimérico (midríase, taquicardia, HAS), serotoninérgico (agitação, hiperreflexia, clonus)'],
        treatment: es
            ? ['1. ABCDE → vía aérea si Glasgow ≤8 o bradipnea', '2. Carbón activado 1 g/kg VO (max 50 g) si <1h de ingesta y vía aérea protegida (CI: ácidos, bases, hidrocarbonos)', '3. Antídotos específicos: naloxona 0,4-2 mg IV/IM (opioides); flumazenil 0,2 mg IV (BZD — con cuidado en epilépticos); N-acetilcisteína 150 mg/kg IV/VO (paracetamol)', '4. Organofosf/pesticidas: atropina 2-4 mg IV hasta secar secreciones + pralidoxima 1-2 g IV', '5. ECG: QT largo → suspender causal + magnesio 2 g IV; QRS ancho (ADT) → bicarbonato 1-2 mEq/kg', '6. Centro de Toxicología (Brasil): 0800 722 6001 — consultar caso complejo']
            : ['1. ABCDE → via aérea se Glasgow ≤8 ou bradipneia', '2. Carvão ativado 1 g/kg VO (máx 50 g) se <1h da ingestão e via aérea protegida (CI: ácidos, bases, hidrocarbonetos)', '3. Antídotos específicos: naloxona 0,4-2 mg IV/IM (opioides); flumazenil 0,2 mg IV (BZD — cuidado em epilépticos); N-acetilcisteína 150 mg/kg IV/VO (paracetamol)', '4. Organofosf/pesticidas: atropina 2-4 mg IV até secar secreções + pralidoxima 1-2 g IV', '5. ECG: QT longo → suspender causal + magnésio 2 g IV; QRS largo (ADT) → bicarbonato 1-2 mEq/kg', '6. Centro de Informação Toxicológica (Brasil): 0800 722 6001 — consultar caso complexo'],
        guidelines: ['AAPCC 2023', 'ESICM Toxicology 2022', 'SBT 2021'],
      ),

      // ── Eclâmpsia / HELLP ─────────────────────────────────────────────────
      _CliCondition(
        id: 'eclampsia',
        label: es ? 'Preeclampsia Grave / Eclampsia / HELLP' : 'Pré-eclâmpsia Grave / Eclâmpsia / Síndrome HELLP',
        protocolId: 'crise_hipertensiva',
        keywords: ['eclamps', 'pre-eclamps', 'pressao gestac', 'gestante hiperten', 'convulsao gravida', 'hellp', 'preeclamps', 'sulfato magn'],
        exams: [es ? 'PA seriada' : 'PA seriada', es ? 'Proteinuria 24h' : 'Proteinúria 24h', es ? 'Plaquetas' : 'Plaquetas', 'TGO/TGP', 'LDH', es ? 'Creatinina' : 'Creatinina'],
        flags: [es ? 'PA ≥160/110 → antihipertensivo inmediato (hidralazina/nifedipina)' : 'PA ≥160/110 em gestante → anti-hipertensivo imediato',
                es ? 'Convulsión → sulfato de magnesio 4–6 g IV' : 'Convulsão → sulfato de magnésio 4–6 g EV (ataque) + 1–2 g/h manutenção',
                es ? 'HELLP → parto inmediato si ≥34 semanas' : 'HELLP → parto imediato se ≥34 semanas'],
        differentials: es
            ? ['Eclampsia vs status epiléptico en embarazo (siempre MgSO4 primero)', 'HELLP vs hígado graso agudo del embarazo (HGAE): transaminasas muy elevadas + hipoglucemia', 'Síndrome hemolítico urémico atípico (SHUa)', 'Púrpura trombocitopénica trombótica (PTT)']
            : ['Eclâmpsia vs status epiléptico na gestação (sempre MgSO4 primeiro)', 'HELLP vs fígado gorduroso agudo da gestação (FGAG): transaminases muito elevadas + hipoglicemia', 'Síndrome hemolítico urêmico atípico (SHUa)', 'Púrpura trombocitopênica trombótica (PTT)'],
        treatment: es
            ? ['1. PA ≥160/110: antihipertensivo IV INMEDIATO — hidralazina 5-10 mg IV c/20 min o labetalol 20 mg IV o nifedipino 10-20 mg VO', '2. Eclampsia/convulsión: MgSO4 4-6 g IV en 20 min → mantenimiento 1-2 g/h (monitorizar reflejo patelar y diuresis)', '3. MgSO4 toxicidad (reflejo abolido, FR <12): gluconato Ca2+ 1 g IV', '4. HELLP: parto si ≥34 sem o inestabilidad; corticoides (dexametasona 12 mg c/12h) si <34 sem', '5. Meta PA: 140-155/90-105 (evitar caídas bruscas — riesgo fetal)', '6. Corticoides fetales si <34 semanas: betametasona 12 mg IM c/24h ×2 dosis']
            : ['1. PA ≥160/110: anti-hipertensivo IV IMEDIATO — hidralazina 5-10 mg IV a cada 20 min ou labetalol 20 mg IV ou nifedipino 10-20 mg VO', '2. Eclâmpsia/convulsão: MgSO4 4-6 g IV em 20 min → manutenção 1-2 g/h (monitorar reflexo patelar e diurese)', '3. Toxicidade MgSO4 (reflexo abolido, FR <12): gluconato de Ca2+ 1 g IV', '4. HELLP: parto se ≥34 sem ou instabilidade; corticoides (dexametasona 12 mg 12/12h) se <34 sem', '5. Meta PA: 140-155/90-105 (evitar quedas bruscas — risco fetal)', '6. Corticoides fetais se <34 semanas: betametasona 12 mg IM 24/24h ×2 doses'],
        guidelines: ['ACOG Preeclampsia 2020', 'FIGO 2022', 'FEBRASGO 2022'],
      ),

      // ── Cefaleia de alto risco ────────────────────────────────────────────
      // IMPORTANTE: keywords exigem qualificadores de risco reais para ativar.
      // "cefal" sozinho NÃO ativa — precisa de pelo menos 1 red flag associada.
      _CliCondition(
        id: 'cefaleia_grave',
        label: es ? 'Cefalea de alto riesgo — descartar HSA / Meningitis' : 'Cefaleia de alto risco — excluir HSA / Meningite',
        protocolId: 'avc_hemorragico',
        // Apenas red flags reais: início em trovoada, pior da vida, sinais meníngeos,
        // déficit focal, alteração consciência, petéquias — não "cefal" isolado.
        keywords: ['trovoada', 'pior cefaleia', 'pior dor de cabeca', 'inicio subito intenso',
                   'rigidez nuca', 'rigidez de nuca', 'meningismo', 'petequi',
                   'kernig', 'brudzinski', 'deficit focal', 'paralisia facial',
                   'pior cefal', 'thunderclap', 'hsa ', 'hemorragia subarac'],
        exams: [es ? 'TC cráneo sin contraste (descartar HSA)' : 'TC crânio sem contraste (excluir HSA)', es ? 'Punción lumbar si TC negativa' : 'Punção lombar se TC negativa', 'Hemoculturas + PCR se febre', 'Hemograma'],
        flags: [es ? '"Peor cefalea de su vida" o inicio súbito → descartar HSA urgente' : '"Pior cefaleia da vida" ou início súbito → excluir HSA urgente',
                es ? 'Déficit focal + cefalea → descartar AVC/hemorragia' : 'Déficit focal + cefaleia → descartar AVC/hemorragia'],
        differentials: es
            ? ['HSA (TC + PL — xantocromía en LCR)', 'Meningitis bacteriana (fiebre + rigidez nucal)', 'ACV hemorrágico intraparenquimatoso', 'Trombosis de seno venoso cerebral (embarazo, ACO, hipercoagulabilidad)', 'Hipertensión intracraneal idiopática (papilededema bilateral)', 'Crisis hipertensiva con encefalopatía']
            : ['HSA (TC + PL — xantocromia no LCR)', 'Meningite bacteriana (febre + rigidez nucal)', 'AVC hemorrágico intraparenquimatoso', 'Trombose de seio venoso cerebral (gestação, ACO, hipercoagulabilidade)', 'Hipertensão intracraniana idiopática (papiledema bilateral)', 'Crise hipertensiva com encefalopatia'],
        treatment: es
            ? ['1. TC cráneo sin contraste URGENTE: diagnóstico en >98% de HSA en primeras 6h', '2. TC negativa + alta sospecha: punción lumbar — xantocromía o >2000 eritrocitos uniformes (no traumática)', '3. HSA confirmada: nimodipino 60 mg VO c/4h por 21 días + neurocirugía urgente (clipaje/coil)', '4. Meningitis: ATB empírico + dexametasona ANTES de TC si no hay signos focales', '5. Analgesia: ketorolac 30 mg IV o metoclopramida 10 mg IV (evitar opioides para no enmascarar síntomas)', '6. NUNCA dar alta sin TC en "peor cefalea de su vida" — mortalidad no tratada HSA: >40%']
            : ['1. TC crânio sem contraste URGENTE: diagnóstico em >98% das HSA nas primeiras 6h', '2. TC negativa + alta suspeita: punção lombar — xantocromia ou >2000 eritrócitos uniformes (não traumática)', '3. HSA confirmada: nimodipino 60 mg VO 4/4h por 21 dias + neurocirurgia urgente (clipagem/coil)', '4. Meningite: ATB empírico + dexametasona ANTES do TC se sem sinais focais', '5. Analgesia: cetorrolaco 30 mg IV ou metoclopramida 10 mg IV (evitar opioides para não mascarar sintomas)', '6. NUNCA dar alta sem TC em "pior cefaleia da vida" — mortalidade HSA não tratada: >40%'],
        guidelines: ['AHA/ASA SAH 2023', 'ESO Headache 2022', 'SBN Cefaleia 2022'],
      ),

      // ── Artrite Séptica ───────────────────────────────────────────────────
      _CliCondition(
        id: 'artrite_septica',
        label: es ? 'Artritis Séptica' : 'Artrite Séptica',
        protocolId: 'sepse',
        keywords: ['artrite septic', 'articulacao quente', 'monoartrite', 'artrite infec', 'artralgia febre', 'artritis septica'],
        exams: [es ? 'Artrocentesis + análisis líquido sinovial' : 'Artrocentese + análise do líquido sinovial', es ? 'Hemocultivos' : 'Hemoculturas', 'PCR/VHS', es ? 'Ácido úrico' : 'Ácido úrico'],
        flags: [es ? 'Artritis séptica → artrocentesis + ATB en <6h (S. aureus más común)' : 'Artrite séptica → artrocentese + ATB em <6h (S. aureus mais comum)'],
        differentials: es
            ? ['Gota aguda (cristales uratos, ácido úrico — puede coexistir con séptica)', 'Artritis reactiva (Reiter: conjuntivitis, uretritis, artritis)', 'Artritis reumatoide (poliarticular, FR, anti-CCP)', 'Artritis pseudogotosa (cristales Ca-pirofosfato, ancianos)', 'Hemartros (anticoagulado o hemofílico)', 'Bursitis infecciosa (limitada a bolsa — no articular)']
            : ['Gota aguda (cristais de uratos, ácido úrico — pode coexistir com séptica)', 'Artrite reativa (Reiter: conjuntivite, uretrite, artrite)', 'Artrite reumatoide (poliarticular, FR, anti-CCP)', 'Artrite pseudogotosa (cristais de Ca-pirofosfato, idosos)', 'Hemartrose (anticoagulado ou hemofílico)', 'Bursite infecciosa (limitada à bolsa — não articular)'],
        treatment: es
            ? ['1. Artrocentesis diagnóstica URGENTE: >50.000 leucocitos/mm³ + >90% PMN = séptica hasta demostrar lo contrario', '2. ATB empírico IV INMEDIATO en <6h (no esperar cultivo): oxacilina 2 g IV c/4h (o ceftriaxona si gram-neg sospechado)', '3. Cultivo del líquido sinovial + hemocultivos (ANTES del ATB si posible, sin demorar)', '4. Drenaje: artrocentesia diaria de evacuación o artroscopía (cadera: drenaje siempre quirúrgico)', '5. ATB 3-4 semanas en total (2-4 semanas adicionales VO tras mejoría IV)', '6. Inmovilización inicial → movilización precoz en 24-48h (previene rigidez)']
            : ['1. Artrocentese diagnóstica URGENTE: >50.000 leucócitos/mm³ + >90% PMN = séptica até provar o contrário', '2. ATB empírico IV IMEDIATO em <6h (não esperar cultura): oxacilina 2 g IV 4/4h (ou ceftriaxona se gram-neg suspeito)', '3. Cultura do líquido sinovial + hemoculturas (ANTES do ATB se possível, sem atrasar)', '4. Drenagem: artrocentese diária de evacuação ou artroscopia (quadril: drenagem sempre cirúrgica)', '5. ATB 3-4 semanas no total (2-4 semanas adicionais VO após melhora IV)', '6. Imobilização inicial → mobilização precoce em 24-48h (previne rigidez)'],
        guidelines: ['IDSA Septic Arthritis 2021', 'BSR 2020', 'SBR 2022'],
      ),

      // ── Anticoagulação / Sangramento ──────────────────────────────────────
      _CliCondition(
        id: 'anticoag_sangr',
        label: es ? 'Sangrado en Anticoagulado / Reversión' : 'Sangramento em Anticoagulado / Reversão',
        protocolId: 'hda_varizeal',
        keywords: ['anticoagulac', 'sangramento ativo', 'heparina reverter', 'varfarina', 'warfarin', 'reverter anticoag', 'inr elev', 'doac'],
        exams: ['INR/TP/TTPA', 'Hemograma', es ? 'Tipaje' : 'Tipagem', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'Warfarina + sangrado grave → vitamina K 10 mg IV + CCP' : 'Varfarina + sangramento grave → vitamina K 10 mg EV + CCP (4 fatores)',
                es ? 'Heparina → protamina 1 mg/100 UI heparina IV' : 'Heparina → protamina 1 mg/100 UI heparina EV',
                es ? 'DOAC → idarucizumab (dabigatrán), andexanet (rivaroxabán/apixabán)' : 'DOAC → idarucizumabe (dabigatrana), andexanete alfa (rivaroxabana/apixabana)'],
        differentials: es
            ? ['Sobrecoagulación por warfarina (INR >4)', 'DOAC con función renal deteriorada (acumulación)', 'Hemorragia espontánea por trombocitopenia', 'Hemofilia A/B (TTPA largo aislado)', 'Coagulación intravascular diseminada (CID)']
            : ['Supercoagulação por varfarina (INR >4)', 'DOAC com função renal deteriorada (acumulação)', 'Hemorragia espontânea por trombocitopenia', 'Hemofilia A/B (TTPA longo isolado)', 'Coagulação intravascular disseminada (CIVD)'],
        treatment: es
            ? ['1. Warfarina + sangrado leve (INR 4-9, sin sangrado): suspender + vitamina K1 1-2,5 mg VO', '2. Warfarina + sangrado grave: vitamina K 10 mg IV + CCP 4F (25-50 U/kg) INMEDIATO', '3. Heparina IV no fraccionada: protamina 1 mg por cada 100 UI de heparina en las últimas 2-3h (máx 50 mg IV lento)', '4. LMWH (HBPM): protamina 1 mg/1 mg HBPM (efectividad parcial ~60%)', '5. Dabigatrán: idarucizumab 5 g IV (2 viales); Rivaroxabán/Apixabán: andexanet alfa IV (dosis según fármaco/momento)', '6. DOAC sin antídoto disponible: CCP 4F 50 U/kg como alternativa']
            : ['1. Varfarina + sangramento leve (INR 4-9, sem sangramento): suspender + vitamina K1 1-2,5 mg VO', '2. Varfarina + sangramento grave: vitamina K 10 mg IV + CCP 4F (25-50 U/kg) IMEDIATO', '3. Heparina IV não fracionada: protamina 1 mg por cada 100 UI de heparina nas últimas 2-3h (máx 50 mg IV lento)', '4. HBPM: protamina 1 mg/1 mg HBPM (efetividade parcial ~60%)', '5. Dabigatrana: idarucizumabe 5 g IV (2 frascos); Rivaroxabana/Apixabana: andexanete alfa IV (dose conforme fármaco/momento)', '6. DOAC sem antídoto disponível: CCP 4F 50 U/kg como alternativa'],
        guidelines: ['ESC Anticoagulation Reversal 2021', 'ACCP 2022', 'SBC Anticoagulação 2023'],
      ),
    ];

    // ── Calcular score de cada condição ──────────────────────────────────────
    // Padded query: espaços nas bordas permitem match de palavras inteiras
    // Ex: ' sca ' NÃO bate em ' cefalea brusca ' mas bate em ' sca ' e ' paciente com sca '
    final qPadded = ' $q ';
    int bestScore  = 0;
    _CliCondition? winner;

    for (final cond in conditions) {
      int score = 0;
      for (final kw in cond.keywords) {
        if (qPadded.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        winner    = cond;
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 2 — LÓGICA CONTEXTUAL (quando score == 0 na msg atual)
    // ════════════════════════════════════════════════════════════════════════
    if (winner == null) {

      // 2a. Cefaleia simples (sem qualificadores de risco) — score 0 porque
      //     os keywords de risco não bateram, mas o sintoma está presente
      if (_has(q, ['cefal', 'dor de cabeca', 'dor cabeca', 'dor de cabe',
                   'cefalea', 'dolor de cabeza'])) {
        final hasFever = _has(q, ['febre', 'fiebre', 'temperatura']);
        final buf2 = StringBuffer();
        if (hasFever) {
          buf2.writeln(es
              ? '## Cefalea con fiebre — investigar: viral, bacteriana, meningitis'
              : '## Cefaleia com febre — investigar: viral, bacteriana, meningite');
          buf2.writeln('');
          buf2.writeln(es ? '## Evaluación clave:' : '## Avaliação-chave:');
          buf2.writeln(es ? '  • Temperatura' : '  • Temperatura');
          buf2.writeln(es ? '  • Hemograma, PCR' : '  • Hemograma, PCR');
          buf2.writeln(es ? '  • Evaluar rigidez nucal en el examen físico' : '  • Avaliar rigidez nucal no exame físico');
          buf2.writeln('');
          buf2.writeln(es ? '## Alerta:' : '## Alerta:');
          buf2.writeln(es
              ? '  • Rigidez nucal + fiebre + cefalea → sospechar meningitis — evaluación urgente'
              : '  • Rigidez nucal + febre + cefaleia → suspeitar meningite — avaliação urgente');
        } else {
          buf2.writeln(es
              ? '## Cefalea — causas frecuentes: migraña, tensional, viral, hipertensión'
              : '## Cefaleia — causas comuns: enxaqueca, tensional, viral, hipertensão');
          buf2.writeln('');
          buf2.writeln(es ? '## Avaliação inicial:' : '## Avaliação inicial:');
          buf2.writeln(es ? '  • PA (descartar crisis hipertensiva)' : '  • PA (descartar crise hipertensiva)');
          buf2.writeln(es ? '  • Temperatura' : '  • Temperatura');
          buf2.writeln(es ? '  • Intensidad (EVA 0–10) y patrón temporal' : '  • Intensidade (EVA 0–10) e padrão temporal');
          buf2.writeln('');
          buf2.writeln(es ? '## Alerta:' : '## Alerta:');
          buf2.writeln(es
              ? '  • Inicio súbito "en trueno" o peor cefalea de su vida → descartar HSA urgente'
              : '  • Início súbito "em trovoada" ou pior da vida → excluir HSA urgente');
        }
        buf2.writeln('');
        buf2.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
        return buf2.toString();
      }

      // 2b. Náusea/vômito simples — sem red flags graves
      if (_has(q, ['nause', 'vomit', 'enjoo', 'emese', 'nausea', 'vomito'])) {
        final hasGravity = _has(q, [
          'dor abdom', 'sangue', 'melena', 'hematemes', 'hipotens', 'choque',
          'trovoada', 'petequi', 'deficit focal', 'glasgow', 'cetoacid',
        ]);
        if (!hasGravity) {
          final buf3 = StringBuffer();
          buf3.writeln(es
              ? '## Síndrome emética — causas frecuentes: gastroenteritis viral, alimentaria, migraña, medicamentosa'
              : '## Síndrome emética — causas comuns: gastroenterite viral, alimentar, enxaqueca, medicamentosa');
          buf3.writeln('');
          buf3.writeln(es ? '## Avaliação inicial:' : '## Avaliação inicial:');
          buf3.writeln(es ? '  • Temperatura (fiebre → causa infecciosa)' : '  • Temperatura (febre → causa infecciosa)');
          buf3.writeln(es ? '  • PA e FC (deshidratación / hipotensión ortostática)' : '  • PA e FC (desidratação / hipotensão ortostática)');
          buf3.writeln(es ? '  • Glucemia capilar' : '  • Glicemia capilar');
          buf3.writeln(es ? '  • Signos de deshidratación (turgencia, mucosas)' : '  • Sinais de desidratação (turgor, mucosas)');
          buf3.writeln('');
          buf3.writeln(es ? '## Alerta:' : '## Alerta:');
          buf3.writeln(es
              ? '  • Dolor abdominal intenso, sangrado, rigidez o alteración de consciencia → urgencia'
              : '  • Dor abdominal intensa, sangramento, rigidez ou rebaixamento → urgência');
          buf3.writeln('');
          buf3.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
          return buf3.toString();
        }
      }

      // 2c. Re-tentativa com qExpanded (histórico + msg atual) — também padded
      if (qHistory.isNotEmpty && qHistory.length > 5) {
        final qExpPadded = ' $qExpanded ';
        int bestExpScore = 0;
        for (final cond in conditions) {
          int sc = 0;
          for (final kw in cond.keywords) {
            if (qExpPadded.contains(kw)) sc++;
          }
          if (sc > bestExpScore) { bestExpScore = sc; winner = cond; }
        }
        if (bestExpScore == 0) winner = null;
      }

      // 2d. Follow-up via última mensagem do assistente
      if (winner == null && _aiHistory.isNotEmpty) {
        final isFollowUp = _has(q, [
          'e a ', 'e o ', 'qual ', 'quando ', 'como ', 'por que', 'pode ',
          'deve ', 'precis', 'protocolo', 'conduta', 'anticoag',
          'tratar', 'tratamento', 'manejo', 'farmaco', 'medicament',
          'y el ', 'y la ', 'cual ', 'cuando ', 'para que',
          'conducta', 'tratamiento',
        ]);
        if (isFollowUp) {
          final lastAI = _normalize(_aiHistory
              .where((m) => m['role'] == 'assistant')
              .map((m) => m['content'] ?? '')
              .lastOrNull ?? '');
          if (lastAI.isNotEmpty) {
            final lastAIPadded = ' $lastAI ';
            int bestCtx = 0;
            for (final cond in conditions) {
              int sc = 0;
              for (final kw in cond.keywords) {
                if (lastAIPadded.contains(kw)) sc++;
              }
              if (sc > bestCtx) { bestCtx = sc; winner = cond; }
            }
            if (bestCtx == 0) winner = null;
          }
        }
      }

      // ════════════════════════════════════════════════════════════════════
      // FASE 2f — CONTEXTO GENÉRICO ESTRUTURADO para doenças não mapeadas
      // Quando nenhuma condição local casa (winner == null), esta fase
      // extrai o termo clínico da query e monta um contexto estruturado
      // que o Gemini usa para buscar na web e responder corretamente.
      // Evita o fallback "preciso de mais detalhes" para queries válidas.
      // ════════════════════════════════════════════════════════════════════
      if (winner == null) {
        // Detectar se a query contém um termo médico/clínico reconhecível
        // (mais de 4 chars, sem ser uma palavra genérica)
        final stopWords = {'para', 'como', 'qual', 'quando', 'sobre', 'tratamento',
                           'medicamento', 'farmaco', 'remedio', 'conduta', 'protocolo',
                           'dose', 'usar', 'deve', 'pode', 'devo', 'fazer', 'tenho',
                           'esta', 'esse', 'essa', 'isso', 'uma', 'tipo', 'caso'};
        final queryTerms = q.split(RegExp(r'\s+'))
            .where((w) => w.length > 4 && !stopWords.contains(w))
            .toList();

        // Verificar se parece uma pergunta clínica legítima (tem termo médico)
        final looksLikeClinical = queryTerms.isNotEmpty && (
          _has(q, ['sindrome', 'doenca', 'infec', 'lesao', 'tumor', 'cancer', 'carcinoma',
                   'insuf', 'crise', 'agud', 'cronic', 'grave', 'leve', 'moderado',
                   'tratament', 'diagnos', 'clinico', 'pacient', 'sintom',
                   'complicac', 'manejo', 'conduta', 'terapia', 'cirurgi',
                   // español
                   'sindrome', 'enfermedad', 'infeccion', 'lesion', 'tumor', 'cancer',
                   'insuficiencia', 'crisis', 'agudo', 'cronico', 'grave',
                   'tratamiento', 'diagnostico', 'clinico', 'paciente', 'sintoma']) ||
          queryTerms.length >= 2
        );

        if (looksLikeClinical && queryTerms.isNotEmpty) {
          // FASE 2f — contexto factual limpo para o Gemini (NÃO exibido ao usuário)
          // Sem markdown, sem títulos, sem instruções visíveis — apenas dados factuais
          // O system prompt já instrui o Gemini a responder naturalmente
          final termLabel = queryTerms.take(3).join(' ');
          final buf2f = StringBuffer();
          buf2f.writeln('CONTEXTO_INTERNO [nao exibir ao usuario]:');
          buf2f.writeln('tema_clinico="$termLabel"');
          buf2f.writeln('query_original="${input.trim()}"');
          buf2f.writeln('base_local="nao mapeado"');
          buf2f.writeln('fontes="Goodman&Gilman,Harrison,DiPiro,Braunwald,Mandell,Cecil,UpToDate,PubMed"');
          // Dados do paciente se disponíveis
          if (_patient.age.isNotEmpty) {
            buf2f.writeln('paciente="${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}"');
          }
          if (_patient.medications.isNotEmpty) {
            buf2f.writeln('medicamentos="${_patient.medications}"');
          }
          return buf2f.toString();
        }

        // 2e. Fallback final — query ambígua ou muito curta (ex: "tratamento" sozinho)
        // → Envia contexto factual mínimo para o Gemini. O system prompt já instrui
        //    o comportamento correto — NÃO repetimos instruções aqui para evitar eco.
        final rawInput = input.trim();
        final prevUserMsg = _aiHistory.isNotEmpty ? (_aiHistory.last['user'] ?? '') : '';
        if (es) {
          final buf2e = StringBuffer();
          buf2e.writeln('CONTEXTO_INTERNO [nao exibir]: query="$rawInput"');
          if (prevUserMsg.isNotEmpty && prevUserMsg != rawInput) {
            buf2e.writeln('mensagem_anterior="$prevUserMsg"');
          }
          if (_patient.age.isNotEmpty) {
            buf2e.writeln('paciente: ${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}'  );
          }
          if (_patient.medications.isNotEmpty) {
            buf2e.writeln('medicamentos: ${_patient.medications}');
          }
          buf2e.writeln('fontes: Goodman&Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed');
          return buf2e.toString();
        } else {
          final buf2e = StringBuffer();
          buf2e.writeln('CONTEXTO_INTERNO [nao exibir]: query="$rawInput"');
          if (prevUserMsg.isNotEmpty && prevUserMsg != rawInput) {
            buf2e.writeln('mensagem_anterior="$prevUserMsg"');
          }
          if (_patient.age.isNotEmpty) {
            buf2e.writeln('paciente: ${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}'  );
          }
          if (_patient.medications.isNotEmpty) {
            buf2e.writeln('medicamentos: ${_patient.medications}');
          }
          buf2e.writeln('fontes: Goodman&Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed');
          return buf2e.toString();
        }
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 3 — RENDERIZAR RESPOSTA ENRIQUECIDA DA CONDIÇÃO VENCEDORA
    // Inclui: red flags → diferenciais → conduta estruturada → doses →
    //         exames → alertas do paciente → referências de diretrizes
    // Este output serve como contexto RAG estruturado para o Gemini.
    // ════════════════════════════════════════════════════════════════════════
    final buf = StringBuffer();

    // ── Cabeçalho ──────────────────────────────────────────────────────────
    buf.writeln('## ${winner.label}');
    buf.writeln('');

    // ── Red flags / Alertas críticos (máx 3) ─────────────────────────────
    if (winner.flags.isNotEmpty) {
      buf.writeln(es ? '### ⚠ Alertas críticos:' : '### ⚠ Alertas críticos:');
      for (final f in winner.flags.take(3)) buf.writeln('  • $f');
      buf.writeln('');
    }

    // ── Diagnósticos diferenciais ─────────────────────────────────────────
    if (winner.differentials.isNotEmpty) {
      buf.writeln(es ? '### Diagnósticos diferenciales a considerar:' : '### Diagnósticos diferenciais a considerar:');
      for (final d in winner.differentials.take(5)) buf.writeln('  • $d');
      buf.writeln('');
    }

    // ── Conduta estruturada / Tratamento por etapas ───────────────────────
    if (winner.treatment.isNotEmpty) {
      buf.writeln(es ? '### Conducta estructurada:' : '### Conduta estruturada:');
      for (final step in winner.treatment) buf.writeln('  $step');
      buf.writeln('');
    }

    // ── Protocolo clínico (conduta imediata do DB interno) ─────────────────
    ProtocolModel? proto;
    if (winner.protocolId != null) {
      try { proto = protocolsDatabase.firstWhere((p) => p.id == winner!.protocolId); }
      catch (_) {}
    }

    if (proto != null) {
      buf.writeln('### ${es ? "Protocolo interno" : "Protocolo interno"} — ${tDB(proto.title)}:');
      final actions = proto.getActions(_lang);
      for (int i = 0; i < actions.length && i < 6; i++) {
        buf.writeln('  ${actions[i]}');
      }
      if (actions.length > 6) {
        buf.writeln(_lang == 'es'
            ? '  → Ver protocolo completo en la pestaña Protocolos'
            : '  → Ver protocolo completo na aba Protocolos');
      }
      buf.writeln('');

      // ── Fármacos do protocolo com doses calculadas ──────────────────────
      final suggestedDrugs = proto.drugs.take(4)
          .map((id) { try { return drugsDatabase.firstWhere((d) => d.id == id); } catch (_) { return null; } })
          .whereType<DrugModel>().toList();

      if (suggestedDrugs.isNotEmpty) {
        if (_patient.weight.isNotEmpty) {
          buf.writeln('### ${_lang == 'es' ? 'Dosis calculadas para este paciente (${_patient.weight} kg):' : 'Doses calculadas para este paciente (${_patient.weight} kg):'}');
          for (final drug in suggestedDrugs) {
            try {
              final dose   = calculateDose(drug);
              final alerts = dose.alerts.take(1).join(' | ');
              buf.writeln('  • ${drug.name}: ${dose.main}${alerts.isNotEmpty ? '  ⚠ $alerts' : ''}');
            } catch (_) {
              final fd = drug.getField(drug.fixedDose, _lang);
              if (fd.isNotEmpty) buf.writeln('  • ${drug.name}: $fd');
            }
          }
        } else {
          buf.writeln('${_lang == 'es' ? 'Fármacos protocolares' : 'Fármacos protocolares'}: ${suggestedDrugs.map((d) => d.name).join(', ')}');
        }
        buf.writeln('');
      }
    }

    // ── Exames-chave (sempre mostrar) ────────────────────────────────────
    if (winner.exams.isNotEmpty) {
      buf.writeln(es ? '### Exámenes clave:' : '### Exames-chave:');
      for (final e in winner.exams.take(6)) buf.writeln('  • $e');
      buf.writeln('');
    }

    // ── Alertas contextuais do paciente ───────────────────────────────────
    final clcrVal = double.tryParse((clcr ?? '').replaceAll(',', '.'));
    if (clcrVal != null && clcrVal > 0 && clcrVal < 60) {
      final lvl = clcrVal < 15 ? '🔴 ALERTA RENAL GRAVE' : clcrVal < 30 ? '🟠 Alerta renal' : '🟡 Atenção renal';
      buf.writeln('$lvl — ${_lang == 'es' ? 'ClCr $clcr mL/min: ajustar todas las dosis renales' : 'ClCr $clcr mL/min: ajustar TODAS as doses renais'}');
      buf.writeln('');
    }
    final ageVal = int.tryParse(_patient.age);
    if (ageVal != null && ageVal >= 75) {
      buf.writeln(_lang == 'es'
          ? '👴 Adulto mayor ≥75 años: reducir dosis opioides/BZD, vigilar delirium, ajustar AINE/IECA.'
          : '👴 Idoso ≥75 anos: reduzir dose opioides/BZD, vigiar delirium, ajustar AINE/IECA.');
      buf.writeln('');
    }
    // Interações com medicamentos do paciente
    if (_patient.medications.trim().isNotEmpty && winner.protocolId != null) {
      final protoProtocol = proto;
      if (protoProtocol != null && protoProtocol.drugs.isNotEmpty) {
        final interList = DrugInteractionService.checkInteractions(
          selectedDrugNames: protoProtocol.drugs.take(3).toList(),
          patientMedicationsText: _patient.medications,
        );
        if (interList.isNotEmpty) {
          buf.writeln(es ? '### ⚠ Interacciones con medicamentos actuales del paciente:' : '### ⚠ Interações com medicamentos atuais do paciente:');
          for (final inter in interList.take(3)) {
            final sevIcon = inter.severity == InteractionSeverity.contraindicated ? '⛔' :
                            inter.severity == InteractionSeverity.major ? '🔴' :
                            inter.severity == InteractionSeverity.moderate ? '🟠' : '🟡';
            buf.writeln('  $sevIcon ${inter.drug1} + ${inter.drug2}: ${inter.effect.length > 120 ? "${inter.effect.substring(0, 120)}..." : inter.effect}');
          }
          buf.writeln('');
        }
      }
    }

    // ── Referências / Diretrizes ──────────────────────────────────────────
    if (winner.guidelines.isNotEmpty) {
      buf.writeln(es ? '### Referencias:' : '### Referências:');
      buf.writeln('  ${winner.guidelines.join(' | ')}');
      buf.writeln('');
    }

    buf.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
    return buf.toString();
  }

  // _normalize exposto internamente para uso em _matchProtocols / _matchDrugs
  String _normalize(String s) => s.toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[ñ]'), 'n');

  bool _has(String q, List<String> words) => words.any((w) => q.contains(w));

  // ── Translations ──────────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _translations = {
    'pt': {
      // ── Dados demográficos ──────────────────────────────────────────────
      'age': 'Idade', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'weight_kg': 'Peso (kg)', 'height_cm': 'Altura (cm)',
      'bio_sex': 'Sexo biológico', 'male': 'Masculino', 'female': 'Feminino',

      // ── Farmacologia ─────────────────────────────────────────────────────
      'drug': 'Fármaco', 'dose': 'Dose calculada', 'route': 'Via',
      'className': 'Classe', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'adverse_events': 'EVENTOS ADVERSOS',
      'renal_alert': 'Alerta renal', 'elderly_alert': 'Alerta em idosos',
      'calculated_dose': 'DOSE CALCULADA', 'edit_to_recalc': 'Edite os dados abaixo para recalcular',
      'drug_sheet': 'FICHA TÉCNICA', 'use_in_cockpit': 'Usar este fármaco no Resumo Clínico',
      'drugs_subtitle': 'Pesquise, abra o card e veja a ficha completa do fármaco.',
      'drugs_search_hint': 'Pesquisar fármaco, classe, mecanismo ou alerta...',
      'drugs_found': 'fármaco(s) encontrado(s)',
      'open': 'abrir', 'back_drugs': 'Voltar para fármacos',
      'use': 'Usar', 'set_main': 'principal',
      'select_drug': 'Selecionar fármaco', 'search_drug_hint': 'Buscar fármaco...',
      'no_drug_selected': 'Nenhum fármaco selecionado',
      'search_add_above': 'Busque e selecione um fármaco acima',

      // ── Protocolos ───────────────────────────────────────────────────────
      'recognize': 'Reconhecer', 'actions': 'Conduta imediata', 'avoid': 'Não fazer',
      'emergency_protocols': 'Protocolos de emergência',
      'quick_access_protocols': 'Acesso rápido a condutas críticas',

      // ── Navegação / Abas ─────────────────────────────────────────────────
      'cockpit': 'Início', 'protocols': 'Protocolos', 'drugs': 'Fármacos',
      'cases': 'Casos', 'prescriptions': 'Ex. Prescrição', 'tools': 'Ferramentas', 'ai': 'IA Clínica',
      'history': 'Histórias Clínicas',

      // ── Cockpit / Paciente ───────────────────────────────────────────────
      'patient_data': 'Dados do paciente',
      'patient_bed': 'Paciente / Leito',
      'tap_to_fill': 'Toque para preencher',
      'hint_bed': 'Ex: Leito 05',
      'hint_meds': 'Ex: AAS 100mg, Enalapril 10mg...',
      'share_case': 'Compartilhar caso',
      'share_history': 'Compartilhar histórico',
      'reminder_set': 'Lembrete definido',
      'reminder_cancel': 'Cancelar lembrete',
      'reminder_label': 'Reavaliar em',
      'reminder_active': 'Lembrete ativo',
      'reminder_none': 'Sem lembrete ativo',
      'reminder_minutes': 'min',
      'reminder_expired': 'Tempo de reavaliação esgotado!',
      'dose_calc': 'Calculadora de dose',
      'medications_optional': 'Medicamentos em uso (opcional)',
      'drug_active': 'fármaco ativo',
      'copy_record': 'Copiar para prontuário',
      'copied_record': 'Copiado para prontuário!',
      'clcr_reduced': 'ClCr reduzido — revisar doses e nefrotóxicos',
      'params_stable': 'Parâmetros estáveis — sem alerta renal crítico',

      // ── Ações gerais ─────────────────────────────────────────────────────
      'send': 'Enviar', 'clear': 'Limpar', 'copied': 'Copiado!',
      'logout': 'Sair', 'login': 'Entrar', 'save': 'Salvar',
      'back': 'Voltar', 'delete': 'Excluir', 'edit': 'Editar',
      'new': 'Novo', 'cancel': 'Cancelar', 'search': 'Pesquisar',
      'admin': 'Admin', 'confirm': 'Confirmar', 'close': 'Fechar',
      'yes': 'Sim', 'no': 'Não', 'ok': 'OK', 'retry': 'Tentar novamente',
      'loading': 'Carregando...', 'error': 'Erro', 'success': 'Sucesso',
      'optional': '(opcional)',

      // ── Ferramentas / Calculadoras ────────────────────────────────────────
      'tools_title': 'Ferramentas Clínicas',
      'tools_subtitle': 'Calculadoras e escalas validadas para uso clínico',
      'score': 'Escore', 'result': 'Resultado', 'interpretation': 'Interpretação',
      'calculate': 'Calcular', 'reset': 'Resetar',
      'sbp': 'PAS (mmHg)', 'dbp': 'PAD (mmHg)',
      'sodium': 'Sódio (mEq/L)', 'chloride': 'Cloro (mEq/L)',
      'bicarbonate': 'Bicarbonato (mEq/L)', 'glucose': 'Glicose (mg/dL)',
      'anion_gap': 'Ânion Gap', 'corrected_na': 'Na corrigido',
      'map_label': 'PAM', 'hemodynamics': 'Hemodinâmica',

      // ── Casos clínicos ───────────────────────────────────────────────────
      'cases_title': 'Casos Clínicos', 'my_cases': 'Meus Casos',
      'public_cases': 'Casos Públicos', 'new_case': 'Novo Caso',
      'case_title': 'Título do caso', 'category': 'Categoria',
      'presentation': 'Apresentação', 'discussion': 'Discussão',
      'diagnosis': 'Diagnóstico', 'treatment': 'Tratamento',
      'no_cases': 'Nenhum caso encontrado',
      'search_cases': 'Buscar casos, diagnósticos...',

      // ── História clínica ─────────────────────────────────────────────────
      'history_title': 'História Clínica',
      'history_subtitle': 'Registro clínico completo',
      'my_histories': 'Minhas HCs',
      'community': 'Comunidade',
      'new_hc': 'Nova HC',
      'chief_complaint': 'Queixa principal',
      'hpi': 'História da doença atual',
      'past_history': 'Antecedentes pessoais',
      'family_history': 'Antecedentes familiares',
      'social_history': 'História social',
      'medications': 'Medicamentos em uso',
      'allergies': 'Alergias',
      'vital_signs': 'Sinais vitais',
      'physical_exam': 'Exame físico',
      'lab_results': 'Exames laboratoriais',
      'imaging': 'Exames de imagem',
      'treatment_plan': 'Plano terapêutico',
      'evolution': 'Evolução',
      'outcome': 'Desfecho',
      'discharge': 'Alta',
      'follow_up': 'Seguimento',
      'final_diagnosis': 'Diagnóstico final',
      'working_diagnosis': 'Hipótese diagnóstica',
      'search_histories': 'Buscar por diagnóstico, queixa, tags...',
      'no_histories': 'Nenhuma história clínica',
      'no_public_histories': 'Nenhuma história pública',
      'copy_hc': 'Copiar HC',
      'dictate': 'Ditar', 'listening': 'Ouvindo...',
      'dictation_not_supported': 'Ditado não suportado',
      'dictation_browser_msg': 'Seu navegador não suporta reconhecimento de voz.\nUse Chrome ou Edge para usar o ditado.',
      // ── Sinais vitais estruturados ────────────────────────────────────────
      'vs_pas': 'PAS', 'vs_pad': 'PAD', 'vs_fc': 'FC', 'vs_fr': 'FR',
      'vs_temp': 'Temp', 'vs_spo2': 'SpO2', 'vs_dextro': 'Dextro',
      'vs_peso': 'Peso', 'vs_mmhg': 'mmHg', 'vs_bpm': 'bpm',
      'vs_irpm': 'irpm', 'vs_celsius': '°C', 'vs_percent': '%',
      'vs_mgdl': 'mg/dL', 'vs_kg': 'kg',
      // ── ECG estruturado ───────────────────────────────────────────────────
      'ecg_ritmo': 'Ritmo', 'ecg_fc': 'FC (bpm)', 'ecg_pr': 'PR (ms)',
      'ecg_qrs': 'QRS (ms)', 'ecg_qt': 'QTc (ms)', 'ecg_eixo': 'Eixo',
      'ecg_st': 'Alterações ST/T', 'ecg_brd': 'Bloqueio', 'ecg_hipertrofia': 'Hipertrofia',
      'ecg_outros': 'Outros achados',
      // ── Lab estruturado ───────────────────────────────────────────────────
      'lab_hb': 'Hb (g/dL)', 'lab_ht': 'Ht (%)', 'lab_leuco': 'Leuco (/mm³)',
      'lab_plaq': 'Plaq (×10³)', 'lab_na': 'Na⁺ (mEq/L)', 'lab_k': 'K⁺ (mEq/L)',
      'lab_cl': 'Cl⁻ (mEq/L)', 'lab_cr': 'Cr (mg/dL)', 'lab_ur': 'Ur (mg/dL)',
      'lab_gli': 'Gli (mg/dL)', 'lab_pcr': 'PCR (mg/L)', 'lab_tni': 'TnI (ng/mL)',
      'lab_bnp': 'BNP (pg/mL)', 'lab_lac': 'Lactato (mmol/L)', 'lab_tp': 'TP (%)',
      'lab_ttpa': 'TTPA (s)', 'lab_tgo': 'TGO (U/L)', 'lab_tgp': 'TGP (U/L)',
      'lab_outros': 'Outros',
      // ── OCR / Foto ───────────────────────────────────────────────────────
      'ocr_photo': 'Foto de laudo', 'ocr_upload': 'Carregar imagem',
      'ocr_extracting': 'Extraindo texto...', 'ocr_done': 'Texto extraído!',
      'ocr_error': 'Erro ao extrair texto', 'ocr_tip': 'Fotografe laudos, telas ou resultados de exames',
      'private': 'Privado', 'public': 'Público',
      'public_history_msg': 'História pública — visível na Comunidade',
      'private_history_msg': 'História privada — somente você vê',
      'anon_note': 'Dados do paciente são anonimizados (iniciais).',
      'delete_history': 'Excluir história clínica?',
      'delete_irreversible': 'Esta ação não pode ser desfeita.',
      'completion': 'preenchido',
      'hidden_by_mod': 'Oculta por moderador',
      'show': 'Mostrar', 'hide': 'Ocultar',
      'delete_permanent': 'Excluir permanentemente',

      // ── IA Clínica ───────────────────────────────────────────────────────
      'ai_title': 'IA Clínica',
      'ai_placeholder': 'Descreva o caso: sintomas, sinais vitais, exames...',
      'ai_send': 'Analisar',
      'ai_disclaimer': 'Apoio educacional. Não substitui avaliação médica presencial.',

      // ── Login / Conta ─────────────────────────────────────────────────────
      'login_title': 'MedCases Pro',
      'login_subtitle': 'Acesso para profissionais de saúde',
      'email': 'E-mail', 'password': 'Senha',
      'sign_in': 'Entrar', 'sign_up': 'Criar conta',
      'forgot_password': 'Esqueci minha senha',
      'name': 'Nome completo', 'profession': 'Profissão', 'institution': 'Instituição',
      'pending_approval': 'Aguardando aprovação',
      'pending_msg': 'Sua conta está sendo analisada. Retorne em breve.',


      // ── Casos clínicos (extras) ─────────────────────────────────────────────
      'cases_subtitle': 'Casos salvos e templates educativos.',
      'library': 'Biblioteca',
      'no_library_cases': 'Nenhum caso na biblioteca.',
      'case_label': 'Caso',
      'back_cases': 'Voltar para casos',
      'years': 'anos',
      'clinical_history': 'História clínica',
      'plan_conduct': 'Plano / Conduta',
      'notes': 'Notas',
      'drugs_label': 'Fármacos',
      'copy_case': 'Copiar caso',
      'delete_case_title': 'Excluir caso?',
      'delete_case_q': 'Excluir caso?',
      'delete_case_confirm': 'Deseja excluir',
      'edit_case': 'Editar caso',
      'case_title_field': 'Título do caso *',
      'history_hint': 'Sintomas, evolução, antecedentes...',
      'additional_notes': 'Notas adicionais',
      'notes_hint': 'Observações, seguimento...',
      'case_title_required': 'Informe um título para o caso',
      'clinical_case_header': 'Caso Clínico',
      'title_label': 'Título',
      'patient_label': 'Paciente',

      // ── Protocolos (extras) ──────────────────────────────────────────────────
      'protocols_subtitle': 'Pesquise e abra o protocolo completo só quando precisar.',
      'search_protocol_hint': 'Pesquisar protocolo: IAM, TEP, choque, hipercalemia...',
      'protocols_found': 'protocolo(s) encontrado(s)',
      'back_protocols': 'Voltar para protocolos',

      // ── IA Clínica (extras) ──────────────────────────────────────────────────
      'ai_subtitle': 'Raciocínio clínico • Somente apoio educacional',
      'copy': 'Copiar',
      'quick_suggestions': 'SUGESTÕES RÁPIDAS',
      'ai_provides': 'O que a IA fornece',
      'ai_feat_dx': 'Hipóteses diagnósticas pelo sintoma',
      'ai_feat_protocol': 'Protocolo clínico sugerido',
      'ai_feat_doses': 'Doses individualizadas (peso, ClCr, idade)',
      'ai_feat_flags': 'Red flags e critérios de urgência',
      'ai_feat_exams': 'Exames complementares úteis',

      // ── Admin ─────────────────────────────────────────────────────────────
      'admin_title': 'Painel Admin',
      'pending_users': 'Usuários pendentes',
      'approve': 'Aprovar', 'reject': 'Rejeitar',
      'all_users': 'Todos os usuários',
      'role': 'Perfil',
    },
    'es': {
      // ── Datos demográficos ────────────────────────────────────────────────
      'age': 'Edad', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'weight_kg': 'Peso (kg)', 'height_cm': 'Altura (cm)',
      'bio_sex': 'Sexo biológico', 'male': 'Masculino', 'female': 'Femenino',

      // ── Farmacología ─────────────────────────────────────────────────────
      'drug': 'Fármaco', 'dose': 'Dosis calculada', 'route': 'Vía',
      'className': 'Clase', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'adverse_events': 'EVENTOS ADVERSOS',
      'renal_alert': 'Alerta renal', 'elderly_alert': 'Alerta en ancianos',
      'calculated_dose': 'DOSIS CALCULADA', 'edit_to_recalc': 'Edite los datos para recalcular',
      'drug_sheet': 'FICHA TÉCNICA', 'use_in_cockpit': 'Usar este fármaco en Resumen Clínico',
      'drugs_subtitle': 'Busque, abra la tarjeta y vea la ficha completa del fármaco.',
      'drugs_search_hint': 'Buscar fármaco, clase, mecanismo o alerta...',
      'drugs_found': 'fármaco(s) encontrado(s)',
      'open': 'abrir', 'back_drugs': 'Volver a fármacos',
      'use': 'Usar', 'set_main': 'principal',
      'select_drug': 'Seleccionar fármaco', 'search_drug_hint': 'Buscar fármaco...',
      'no_drug_selected': 'Ningún fármaco seleccionado',
      'search_add_above': 'Busque y seleccione un fármaco arriba',

      // ── Protocolos ───────────────────────────────────────────────────────
      'recognize': 'Reconocer', 'actions': 'Conducta inmediata', 'avoid': 'No hacer',
      'emergency_protocols': 'Protocolos de emergencia',
      'quick_access_protocols': 'Acceso rápido a conductas críticas',

      // ── Navegación / Pestañas ─────────────────────────────────────────────
      'cockpit': 'Inicio', 'protocols': 'Protocolos', 'drugs': 'Fármacos',
      'cases': 'Casos', 'prescriptions': 'Ej. Prescripción', 'tools': 'Herramientas', 'ai': 'IA Clínica',
      'history': 'Historias Clínicas',

      // ── Cockpit / Paciente ────────────────────────────────────────────────
      'patient_data': 'Datos del paciente',
      'patient_bed': 'Paciente / Cama',
      'tap_to_fill': 'Toque para completar',
      'hint_bed': 'Ej: Cama 05',
      'hint_meds': 'Ej: AAS 100mg, Enalapril 10mg...',
      'share_case': 'Compartir caso',
      'share_history': 'Compartir historial',
      'reminder_set': 'Recordatorio definido',
      'reminder_cancel': 'Cancelar recordatorio',
      'reminder_label': 'Reevaluar en',
      'reminder_active': 'Recordatorio activo',
      'reminder_none': 'Sin recordatorio activo',
      'reminder_minutes': 'min',
      'reminder_expired': '¡Tiempo de reevaluación agotado!',
      'dose_calc': 'Calculadora de dosis',
      'medications_optional': 'Medicamentos en uso (opcional)',
      'drug_active': 'fármaco activo',
      'copy_record': 'Copiar a historia clínica',
      'copied_record': '¡Copiado a historia clínica!',
      'clcr_reduced': 'ClCr reducido — revisar dosis y nefrotóxicos',
      'params_stable': 'Parámetros estables — sin alerta renal crítica',

      // ── Acciones generales ────────────────────────────────────────────────
      'send': 'Enviar', 'clear': 'Limpiar', 'copied': '¡Copiado!',
      'logout': 'Salir', 'login': 'Acceder', 'save': 'Guardar',
      'back': 'Volver', 'delete': 'Eliminar', 'edit': 'Editar',
      'new': 'Nuevo', 'cancel': 'Cancelar', 'search': 'Buscar',
      'admin': 'Admin', 'confirm': 'Confirmar', 'close': 'Cerrar',
      'yes': 'Sí', 'no': 'No', 'ok': 'OK', 'retry': 'Reintentar',
      'loading': 'Cargando...', 'error': 'Error', 'success': 'Éxito',
      'optional': '(opcional)',

      // ── Herramientas / Calculadoras ───────────────────────────────────────
      'tools_title': 'Herramientas Clínicas',
      'tools_subtitle': 'Calculadoras y escalas validadas para uso clínico',
      'score': 'Puntuación', 'result': 'Resultado', 'interpretation': 'Interpretación',
      'calculate': 'Calcular', 'reset': 'Reiniciar',
      'sbp': 'TAS (mmHg)', 'dbp': 'TAD (mmHg)',
      'sodium': 'Sodio (mEq/L)', 'chloride': 'Cloro (mEq/L)',
      'bicarbonate': 'Bicarbonato (mEq/L)', 'glucose': 'Glucosa (mg/dL)',
      'anion_gap': 'Anión Gap', 'corrected_na': 'Na corregido',
      'map_label': 'PAM', 'hemodynamics': 'Hemodinámica',

      // ── Casos clínicos ────────────────────────────────────────────────────
      'cases_title': 'Casos Clínicos', 'my_cases': 'Mis Casos',
      'public_cases': 'Casos Públicos', 'new_case': 'Nuevo Caso',
      'case_title': 'Título del caso', 'category': 'Categoría',
      'presentation': 'Presentación', 'discussion': 'Discusión',
      'diagnosis': 'Diagnóstico', 'treatment': 'Tratamiento',
      'no_cases': 'Ningún caso encontrado',
      'search_cases': 'Buscar casos, diagnósticos...',

      // ── Historia clínica ──────────────────────────────────────────────────
      'history_title': 'Historia Clínica',
      'history_subtitle': 'Registro clínico completo',
      'my_histories': 'Mis HCs',
      'community': 'Comunidad',
      'new_hc': 'Nueva HC',
      'chief_complaint': 'Motivo de consulta',
      'hpi': 'Historia de la enfermedad actual',
      'past_history': 'Antecedentes personales',
      'family_history': 'Antecedentes familiares',
      'social_history': 'Historia social',
      'medications': 'Medicamentos en uso',
      'allergies': 'Alergias',
      'vital_signs': 'Signos vitales',
      'physical_exam': 'Examen físico',
      'lab_results': 'Exámenes de laboratorio',
      'imaging': 'Estudios de imagen',
      'treatment_plan': 'Plan terapéutico',
      'evolution': 'Evolución',
      'outcome': 'Desenlace',
      'discharge': 'Alta',
      'follow_up': 'Seguimiento',
      'final_diagnosis': 'Diagnóstico final',
      'working_diagnosis': 'Hipótesis diagnóstica',
      'search_histories': 'Buscar por diagnóstico, queja, etiquetas...',
      'no_histories': 'Ninguna historia clínica',
      'no_public_histories': 'Ninguna historia pública',
      'copy_hc': 'Copiar HC',
      'dictate': 'Dictar', 'listening': 'Escuchando...',
      'dictation_not_supported': 'Dictado no soportado',
      'dictation_browser_msg': 'Su navegador no soporta reconocimiento de voz.\nUse Chrome o Edge para usar el dictado.',
      // ── Signos vitales estructurados ──────────────────────────────────────
      'vs_pas': 'TAS', 'vs_pad': 'TAD', 'vs_fc': 'FC', 'vs_fr': 'FR',
      'vs_temp': 'Temp', 'vs_spo2': 'SpO2', 'vs_dextro': 'Dextro',
      'vs_peso': 'Peso', 'vs_mmhg': 'mmHg', 'vs_bpm': 'lpm',
      'vs_irpm': 'rpm', 'vs_celsius': '°C', 'vs_percent': '%',
      'vs_mgdl': 'mg/dL', 'vs_kg': 'kg',
      // ── ECG estructurado ─────────────────────────────────────────────────
      'ecg_ritmo': 'Ritmo', 'ecg_fc': 'FC (lpm)', 'ecg_pr': 'PR (ms)',
      'ecg_qrs': 'QRS (ms)', 'ecg_qt': 'QTc (ms)', 'ecg_eixo': 'Eje',
      'ecg_st': 'Alteraciones ST/T', 'ecg_brd': 'Bloqueo', 'ecg_hipertrofia': 'Hipertrofia',
      'ecg_outros': 'Otros hallazgos',
      // ── Lab estructurado ─────────────────────────────────────────────────
      'lab_hb': 'Hb (g/dL)', 'lab_ht': 'Hto (%)', 'lab_leuco': 'Leuco (/mm³)',
      'lab_plaq': 'Plaq (×10³)', 'lab_na': 'Na⁺ (mEq/L)', 'lab_k': 'K⁺ (mEq/L)',
      'lab_cl': 'Cl⁻ (mEq/L)', 'lab_cr': 'Cr (mg/dL)', 'lab_ur': 'Ur (mg/dL)',
      'lab_gli': 'Gli (mg/dL)', 'lab_pcr': 'PCR (mg/L)', 'lab_tni': 'TnI (ng/mL)',
      'lab_bnp': 'BNP (pg/mL)', 'lab_lac': 'Lactato (mmol/L)', 'lab_tp': 'TP (%)',
      'lab_ttpa': 'TTPA (s)', 'lab_tgo': 'TGO (U/L)', 'lab_tgp': 'TGP (U/L)',
      'lab_outros': 'Otros',
      // ── OCR / Foto ───────────────────────────────────────────────────────
      'ocr_photo': 'Foto de informe', 'ocr_upload': 'Cargar imagen',
      'ocr_extracting': 'Extrayendo texto...', 'ocr_done': '¡Texto extraído!',
      'ocr_error': 'Error al extraer texto', 'ocr_tip': 'Fotografíe informes, pantallas o resultados de exámenes',
      'private': 'Privado', 'public': 'Público',
      'public_history_msg': 'Historia pública — visible en la Comunidad',
      'private_history_msg': 'Historia privada — solo usted la ve',
      'anon_note': 'Los datos del paciente están anonimizados (iniciales).',
      'delete_history': '¿Eliminar historia clínica?',
      'delete_irreversible': 'Esta acción no se puede deshacer.',
      'completion': 'completado',
      'hidden_by_mod': 'Oculta por moderador',
      'show': 'Mostrar', 'hide': 'Ocultar',
      'delete_permanent': 'Eliminar permanentemente',

      // ── IA Clínica ────────────────────────────────────────────────────────
      'ai_title': 'IA Clínica',
      'ai_placeholder': 'Describa el caso: síntomas, signos vitales, exámenes...',
      'ai_send': 'Analizar',
      'ai_disclaimer': 'Apoyo educacional. No sustituye la evaluación médica presencial.',

      // ── Login / Cuenta ────────────────────────────────────────────────────
      'login_title': 'MedCases Pro',
      'login_subtitle': 'Acceso para profesionales de salud',
      'email': 'Correo electrónico', 'password': 'Contraseña',
      'sign_in': 'Acceder', 'sign_up': 'Crear cuenta',
      'forgot_password': 'Olvidé mi contraseña',
      'name': 'Nombre completo', 'profession': 'Profesión', 'institution': 'Institución',
      'pending_approval': 'Esperando aprobación',
      'pending_msg': 'Su cuenta está siendo revisada. Vuelva pronto.',


      // ── Casos clínicos (extras) ─────────────────────────────────────────────
      'cases_subtitle': 'Casos guardados y templates educativos.',
      'library': 'Biblioteca',
      'no_library_cases': 'Sin casos en la biblioteca.',
      'case_label': 'Caso',
      'back_cases': 'Volver a casos',
      'years': 'años',
      'clinical_history': 'Historia clínica',
      'plan_conduct': 'Plan / Conducta',
      'notes': 'Notas',
      'drugs_label': 'Fármacos',
      'copy_case': 'Copiar caso',
      'delete_case_title': '¿Eliminar caso?',
      'delete_case_q': '¿Eliminar caso?',
      'delete_case_confirm': '¿Desea eliminar',
      'edit_case': 'Editar caso',
      'case_title_field': 'Título del caso *',
      'history_hint': 'Síntomas, evolución, antecedentes...',
      'additional_notes': 'Notas adicionales',
      'notes_hint': 'Observaciones, seguimiento...',
      'case_title_required': 'Ingrese un título para el caso',
      'clinical_case_header': 'Caso Clínico',
      'title_label': 'Título',
      'patient_label': 'Paciente',

      // ── Protocolos (extras) ──────────────────────────────────────────────────
      'protocols_subtitle': 'Busque y abra el protocolo completo solo cuando lo necesite.',
      'search_protocol_hint': 'Buscar protocolo: IAM, TEP, choque, hipercalemia...',
      'protocols_found': 'protocolo(s) encontrado(s)',
      'back_protocols': 'Volver a protocolos',

      // ── IA Clínica (extras) ──────────────────────────────────────────────────
      'ai_subtitle': 'Razonamiento clínico • Solo apoyo educativo',
      'copy': 'Copiar',
      'quick_suggestions': 'SUGERENCIAS RÁPIDAS',
      'ai_provides': 'Qué proporciona la IA',
      'ai_feat_dx': 'Hipótesis diagnósticas por síntoma',
      'ai_feat_protocol': 'Protocolo clínico sugerido',
      'ai_feat_doses': 'Dosis individualizadas (peso, ClCr, edad)',
      'ai_feat_flags': 'Red flags y criterios de urgencia',
      'ai_feat_exams': 'Exámenes complementarios útiles',

      // ── Admin ─────────────────────────────────────────────────────────────
      'admin_title': 'Panel Admin',
      'pending_users': 'Usuarios pendientes',
      'approve': 'Aprobar', 'reject': 'Rechazar',
      'all_users': 'Todos los usuarios',
      'role': 'Perfil',
    },
  };
}

// ---------------------------------------------------------------------------
// Classe auxiliar para sistema de pontuação do _buildLocalAnswer
// ---------------------------------------------------------------------------
class _CliCondition {
  final String id;
  final String label;
  final String? protocolId;
  final List<String> keywords;
  final List<String> exams;
  final List<String> flags;
  /// Diagnósticos diferenciais a considerar
  final List<String> differentials;
  /// Etapas de tratamento estruturado (contexto RAG para Gemini)
  final List<String> treatment;
  /// Diretrizes/guidelines de referência
  final List<String> guidelines;
  const _CliCondition({
    required this.id,
    required this.label,
    this.protocolId,
    required this.keywords,
    required this.exams,
    required this.flags,
    this.differentials = const [],
    this.treatment = const [],
    this.guidelines = const [],
  });
}
