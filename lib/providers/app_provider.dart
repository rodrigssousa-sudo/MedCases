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

  // ── Estado — Histórias Clínicas ───────────────────────────────────────────
  List<ClinicalHistoryModel> _myHistories = [];
  List<ClinicalHistoryModel> _publicHistories = [];
  bool _isLoadingPublic = false;
  String _publicLoadError = '';

  String get publicLoadError => _publicLoadError;

  // ── Rastreamento de uso ────────────────────────────────────────────────────
  Timer? _usageTimer;
  int _sessionSeconds = 0; // segundos acumulados nesta sessão (flush a cada 60s)

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

  List<DrugModel> get drugsDB => drugsDatabase;
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

    // 2️⃣ Carrega chave OpenAI com AWAIT — garante hasAiKey=true antes da UI montar.
    //    Timeout 5s para não travar login em redes lentas; falha silenciosa = modo local.
    if (_openAiKey.isEmpty) {
      await _loadAiKeyFromFirestore(user.uid).timeout(
        const Duration(seconds: 5),
        onTimeout: () { _aiKeyLoading = false; },
      );
    }

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

  // ── Timer de uso — incrementa 1s/s, grava no Firestore a cada 60s ──────────
  void _startUsageTimer(String uid) {
    _usageTimer?.cancel();
    _sessionSeconds = 0;
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
      // Flush a cada 60 segundos → 1 escrita no Firestore por minuto de uso
      if (_sessionSeconds % 60 == 0) {
        FirestoreService.incrementUsage(uid, 60);
      }
    });
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
  }

  void clearUser() {
    _stopUsageTimer();
    _currentUser = null;
    _firebaseReady = false;
    _favDrugs = {};
    _favProtocols = {};
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
  //  1. config/app_settings.openAiKey  → chave do app (admin configura, todos usam)
  //  2. users/{uid}/prefs/settings.openAiKey → chave individual (legado / admin)
  //  3. SharedPreferences local → fallback offline
  Future<void> _loadAiKeyFromFirestore(String uid) async {
    try {
      // 1️⃣ Tenta chave global do app primeiro
      final appKey = await FirestoreService.loadAppAiKey();
      if (appKey.isNotEmpty) {
        _openAiKey = appKey;
        _aiKeyLoading = false;
        notifyListeners();
        // Cache local para funcionar offline
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', uid), appKey);
        return;
      }

      // 2️⃣ Fallback: chave individual do usuário (legado)
      final userKey = await FirestoreService.loadAiKey(uid);
      if (userKey.isNotEmpty) {
        _openAiKey = userKey;
        _aiKeyLoading = false;
        notifyListeners();
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', uid), userKey);
        return;
      }

      // Sem chave em nenhuma fonte
      _aiKeyLoading = false;
      notifyListeners();
    } catch (_) {
      // 3️⃣ Sem rede: tenta cache local
      try {
        final p = await SharedPreferences.getInstance();
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
      } catch (_) {}
      _aiKeyLoading = false;
      notifyListeners();
    }
  }

  // ── Sincronização background com Firestore ────────────────────────────────
  // Chamado APÓS _loadFromLocal — atualiza silenciosamente quando há rede
  Future<void> _syncFromFirestore(String uid) async {
    try {
      final favDrugs     = await FirestoreService.loadFavDrugs(uid);
      final favProtocols = await FirestoreService.loadFavProtocols(uid);
      final cases        = await FirestoreService.loadCases(uid);
      _favDrugs     = favDrugs;
      _favProtocols = favProtocols;
      _customCases  = cases;
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
      final favKey   = _k('favDrugs',      uid);
      final protKey  = _k('favProtocols',  uid);
      final caseKey  = _k('customCases',   uid);
      final histKey  = _k('myHistories',   uid);

      _favDrugs     = (p.getStringList(favKey)  ?? p.getStringList('favDrugs')  ?? []).toSet();
      _favProtocols = (p.getStringList(protKey) ?? p.getStringList('favProtocols') ?? []).toSet();

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
      await p.setStringList(_k('favDrugs',     u), _favDrugs.toList());
      await p.setStringList(_k('favProtocols', u), _favProtocols.toList());
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
  /// Persiste em config/app_settings.openAiKey + atualiza estado local.
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
  /// Fluxo redirect OAuth (Safari/web):
  ///   1. JS em index.html salva token + seta 'medcases_gsi_pending' SINCRONAMENTE
  ///      antes do Flutter carregar (no mesmo script, antes do bootFlutter).
  ///   2. Este método detecta a flag, lê o token diretamente do localStorage
  ///      e valida via tokeninfo — sem depender do fetch assíncrono do JS.
  ///   3. Se o email ainda não chegou (fetch do JS ainda em andamento),
  ///      buscamos via tokeninfo direto aqui no Dart.
  Future<void> checkGeminiSession() async {
    try {
      if (kIsWeb) {
        // Limpa flag de modal órfã (pode sobrar de tentativas anteriores)
        _webRemoveLS('medcases_gsi_modal_opened');

        // ── Detecta retorno do redirect OAuth ───────────────────────────────
        final pending = _webGetLS('medcases_gsi_pending');
        if (pending == 'true') {
          _webRemoveLS('medcases_gsi_pending');

          final token = _webGetLS('gemini_access_token');
          if (token != null && token.isNotEmpty) {
            _geminiConnected = true;
            _geminiEmail = _webGetLS('gemini_google_email') ?? '';
            if (_geminiEmail.isEmpty) {
              await Future.delayed(const Duration(milliseconds: 600));
              _geminiEmail = _webGetLS('gemini_google_email') ?? '';
            }
            if (_geminiEmail.isEmpty) {
              _geminiEmail = await GeminiService.connectedEmail() ?? '';
            }
            notifyListeners();
            return;
          } else {
          }
        }
      }

      // ── Verificação normal de sessão existente ───────────────────────────
      final connected = await GeminiService.isConnected()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (connected) {
        _geminiConnected = true;
        _geminiEmail = await GeminiService.connectedEmail() ?? '';
        debugPrint('[checkGeminiSession] sessão existente — $_geminiEmail');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[checkGeminiSession] erro: $e');
      // Silencia — nunca mostra banner aqui
      _geminiConnected = false;
      _geminiEmail = '';
    }
  }


  /// Lê um valor do localStorage via eval — resistente ao SES lockdown do Firebase.
  /// O Firebase Auth injeta lockdown-install.js que congela proxies do dart:js,
  /// fazendo context['localStorage'].callMethod('getItem') retornar null.
  /// eval() acessa o localStorage nativo do browser, sem passar pelo proxy.
  String? _webGetLS(String key) {
    if (!kIsWeb) return null;
    try {
      final safeKey = key.replaceAll("'", "\\'");
      final result = js_interop.context
          .callMethod('eval', ["localStorage.getItem('$safeKey')"]);
      if (result == null || result.toString() == 'null') return null;
      return result.toString();
    } catch (_) {
      return null;
    }
  }

  /// Remove uma chave do localStorage via eval — resistente ao SES lockdown.
  void _webRemoveLS(String key) {
    if (!kIsWeb) return;
    try {
      final safeKey = key.replaceAll("'", "\\'");
      js_interop.context.callMethod('eval', ["localStorage.removeItem('$safeKey')"]);
    } catch (_) {}
  }

  /// Retorna sumários dos protocolos cujos títulos/reconhecer contenham keywords da query
  List<String> _matchProtocols(String normalizedQuery) {
    // Protocolos de alta emergência exigem ≥2 palavras da query para match,
    // evitando falsos positivos (ex: "cefaleia" na gripe injeta AVC/HSA).
    const _highRiskIds = {
      'avc_hemorragico', 'avc_isquemico', 'pcr_adulto', 'choque_cardiogenico',
      'hsa', 'meningite', 'sepse', 'iam_congestao', 'tep', 'status_epilepticus',
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

  /// Verifica se a pergunta é uma query direta/nova (não deve herdar histórico)
  bool _isDirectQuery(String input) {
    final q = input.toLowerCase().trim();
    // Prefixos que indicam query direta ao Gemini/IA — não misturar histórico
    final directPrefixes = [
      'buscar em gemini:', 'buscar gemini:', 'buscar:', 'pesquisar:',
      'gemini:', 'ia:', 'perguntar:', 'consultar:',
      'search:', 'busca:', 'o que é ', 'o que e ',
      'qual é ', 'qual e ', 'como ', 'quando ', 'por que ', 'porque ',
      'explique ', 'explica ', 'defina ', 'define ',
    ];
    if (directPrefixes.any((p) => q.startsWith(p))) return true;
    // Pergunta curta e conceitual (sem sintomas clínicos) — não herdar histórico
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

  /// Chamada principal — modo HÍBRIDO: base local sempre roda + IA enriquece
  ///
  /// Prioridade:
  ///  1. Gemini OAuth (conta Google do usuário) — se conectado
  ///  2. OpenAI GPT (chave no Firestore)        — se disponível
  ///  3. Base local rule-based                  — sempre funciona
  Future<String> buildAIAnswer(String input) async {
    // ── Passo 1: Matching local SEMPRE roda ──────────────────────────────────
    final expandedInput = _expandedQuery(input);
    final normalized    = _normalize(expandedInput);
    final protocols     = _matchProtocols(normalized);
    final drugs         = _matchDrugs(normalized);

    // ── System prompt clínico (mesmo para Gemini e OpenAI) ───────────────────
    final systemPrompt = AiService.buildClinicalSystemPrompt(
      lang: _lang,
      matchedProtocolSummaries: protocols,
      matchedDrugSummaries: drugs,
      localAnswerContext: _buildLocalAnswer(input),
      patientAge: _patient.age.isNotEmpty ? _patient.age : null,
      patientSex: _patient.sex.isNotEmpty ? _patient.sex : null,
      patientWeight: _patient.weight.isNotEmpty ? _patient.weight : null,
      patientClcr: clcr,
      patientMedications: _patient.medications.isNotEmpty ? _patient.medications : null,
    );

    // ── Passo 2: Gemini OAuth tem prioridade (conta Google do usuário) ────────
    if (_geminiConnected) {
      final geminiResult = await GeminiService.chat(
        userMessage: input,
        systemPrompt: systemPrompt,
        history: List.unmodifiable(_aiHistory),
      );

      if (!geminiResult.isError) {
        _aiHistory
          ..add({'role': 'user', 'content': input})
          ..add({'role': 'assistant', 'content': geminiResult.text});
        while (_aiHistory.length > 20) _aiHistory.removeAt(0);
        return geminiResult.text;
      }

      // Gemini falhou — trata erro
      switch (geminiResult.errorCode) {
        case 'token_expired':
          // Sessão expirou → marca desconectado, cai para local
          _geminiConnected = false;
          _geminiEmail = '';
          notifyListeners();
          return _lang == 'es'
              ? '⚠️ Sesión de Google expirada. Reconecta tu cuenta en la configuración.\n\n'
                '${_buildLocalAnswer(input)}'
              : '⚠️ Sessão Google expirada. Reconecte sua conta nas configurações.\n\n'
                '${_buildLocalAnswer(input)}';
        case 'quota':
          return _lang == 'es'
              ? '⚠️ Límite de uso de Gemini alcanzado. Inténtalo más tarde.\n\n'
                '${_buildLocalAnswer(input)}'
              : '⚠️ Limite de uso do Gemini atingido. Tente novamente mais tarde.\n\n'
                '${_buildLocalAnswer(input)}';
        case 'blocked':
          // Conteúdo bloqueado pelo safety filter → fallback silencioso
          return _buildLocalAnswer(input);
        default:
          // Erro de rede ou desconhecido → fallback silencioso para local
          return _buildLocalAnswer(input);
      }
    }

    // ── Passo 3: Sem Gemini → tenta OpenAI (legado) ───────────────────────────
    if (_openAiKey.isEmpty) {
      return _buildLocalAnswer(input);
    }

    final result = await AiService.chat(
      apiKey: _openAiKey,
      userMessage: input,
      systemPrompt: systemPrompt,
      history: List.unmodifiable(_aiHistory),
    );

    // ── Passo 4: Tratamento de erros OpenAI ──────────────────────────────────
    if (result.isError) {
      switch (result.errorCode) {
        case 'invalid_key':
          return _lang == 'es'
              ? '⚠️ Clave de API inválida. Verifica tu clave en la configuración del chat.\n\n'
                'Mientras tanto, aquí está la respuesta de nuestra base local:\n\n'
                '${_buildLocalAnswer(input)}'
              : '⚠️ Chave de API inválida. Verifique sua chave na configuração do chat.\n\n'
                'Enquanto isso, aqui está a resposta da nossa base local:\n\n'
                '${_buildLocalAnswer(input)}';
        case 'quota':
          return _lang == 'es'
              ? '⚠️ Límite de uso de la API alcanzado. Revisa tu cuenta en platform.openai.com.\n\n'
                'Respuesta de nuestra base local:\n\n'
                '${_buildLocalAnswer(input)}'
              : '⚠️ Limite de uso da API atingido. Verifique sua conta em platform.openai.com.\n\n'
                'Resposta da nossa base local:\n\n'
                '${_buildLocalAnswer(input)}';
        default:
          return _buildLocalAnswer(input);
      }
    }

    // ── Passo 5: Sucesso → adiciona ao histórico multi-turn ──────────────────
    _aiHistory
      ..add({'role': 'user', 'content': input})
      ..add({'role': 'assistant', 'content': result.text});
    // Limita a 10 pares (20 mensagens) para não explodir tokens
    while (_aiHistory.length > 20) {
      _aiHistory.removeAt(0);
    }

    return result.text;
  }

  /// Resposta local (rule-based) — fallback quando não há chave ou sem rede.
  ///
  /// ARQUITETURA: sistema de pontuação por condição.
  /// Cada condição clínica acumula score (+1 por keyword encontrada).
  /// Apenas a condição com maior score é exibida — elimina o dump
  /// incoerente de hipóteses desconexas (ex: cefaleia + fasciíte juntas).
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
    // FASE 0 — FARMACOLOGIA DIRETA (prioridade absoluta)
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
        final askingVia   = _has(qExpanded, ['via ', 'via de', 'forma de admin', 'como admin', 'como dar', 'rota', 'modo de', 'administracion']);
        final askingDose  = _has(qExpanded, ['dose', 'dosagem', 'posolog', 'dosis']);
        final askingMech  = _has(qExpanded, ['mecanismo', 'como funciona', 'por que', 'mecanismo de acao', 'mecanismo de accion']);
        final askingAdv   = _has(qExpanded, ['adverso', 'colateral', 'reacao', 'toxicidad', 'efectos sec', 'efeito']);
        final askingInter = _has(qExpanded, ['interacao', 'interaccion', 'interage', 'compativel']);
        final askingCI    = _has(qExpanded, ['contraindicacao', 'contraindicado', 'nao usar', 'contraindicacion']);
        final askingInd   = _has(qExpanded, ['indicacao', 'indicado', 'para que', 'quando usar', 'sirve', 'indicacion']);

        final buf = StringBuffer();
        buf.writeln(es ? '## Información farmacológica:' : '## Informações farmacológicas:');
        buf.writeln('');

        for (final drug in drugsDatabase) {
          final dName = _normalize(drug.name);
          final words = qExpanded.split(RegExp(r'\s+')).where((w) => w.length > 3);
          if (!words.any((w) => dName.contains(w))) continue;

          buf.writeln('### ${drug.name}');
          if (askingVia || (!askingDose && !askingMech && !askingAdv && !askingInter && !askingCI && !askingInd)) {
            if (drug.route.isNotEmpty) buf.writeln('  **${es ? "Vía" : "Via"}:** ${drug.route}');
          }
          if (askingDose || (!askingVia && !askingMech && !askingAdv && !askingInter && !askingCI && !askingInd)) {
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
          if (askingMech) {
            final mech = drug.getField(drug.mechanism, _lang);
            if (mech.isNotEmpty) buf.writeln('  **Mecanismo:** $mech');
          }
          if (askingAdv) {
            final advList = drug.getAdverse(_lang);
            if (advList.isNotEmpty) buf.writeln('  **${es ? "Efectos adversos" : "Efeitos adversos"}:** ${advList.take(5).join(', ')}');
          }
          if (askingCI) {
            final warn = drug.getField(drug.warning, _lang);
            if (warn.isNotEmpty) buf.writeln('  **${es ? "Contraindicaciones / Alertas" : "Contraindicações / Alertas"}:** ${warn.length > 200 ? "${warn.substring(0, 200)}..." : warn}');
          }
          if (askingInd) {
            final cls = drug.getField(drug.className, _lang);
            if (cls.isNotEmpty) buf.writeln('  **${es ? "Clase / Uso" : "Classe / Uso"}:** $cls');
          }
          if (askingInter) {
            final interList = DrugInteractionService.checkInteractions(
              selectedDrugNames: [drug.name],
              patientMedicationsText: _patient.medications,
            );
            if (interList.isNotEmpty) {
              buf.writeln('  **${es ? "Interacciones relevantes" : "Interações relevantes"}:**');
              for (final inter in interList.take(4)) {
                final sev = inter.severity == InteractionSeverity.contraindicated
                    ? '⛔ Contraindicado'
                    : inter.severity == InteractionSeverity.major
                        ? '🔴 ${es ? "Mayor" : "Maior"}'
                        : inter.severity == InteractionSeverity.moderate
                            ? '🟠 ${es ? "Moderada" : "Moderada"}'
                            : '🟡 ${es ? "Menor" : "Menor"}';
                final eff = inter.effect;
                buf.writeln('    $sev — ${inter.drug1} + ${inter.drug2}: ${eff.length > 100 ? "${eff.substring(0, 100)}..." : eff}');
              }
            } else {
              buf.writeln('  ${es ? "No se encontraron interacciones registradas." : "Nenhuma interação registrada com os medicamentos atuais."}');
            }
          }
          final clcrPharma = double.tryParse((clcr ?? '').replaceAll(',', '.'));
          if (clcrPharma != null && clcrPharma > 0 && clcrPharma < 45) {
            final ra = drug.getField(drug.renalAlert, _lang);
            if (ra.isNotEmpty) buf.writeln('  ⚠ **${es ? "Alerta renal (ClCr $clcr)" : "Alerta renal (ClCr $clcr)"}:** ${ra.length > 150 ? "${ra.substring(0, 150)}..." : ra}');
          }
          buf.writeln('');
        }

        if (buf.length > 50) {
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
      ),

      // ── IAM / SCA ─────────────────────────────────────────────────────────
      _CliCondition(
        id: 'iam',
        label: es ? 'Síndrome Coronario Agudo (IAM/Angina)' : 'Síndrome Coronariana Aguda (IAM/Angina)',
        protocolId: 'iam_congestao',
        keywords: ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', 'sca', 'troponina', 'supradesnivel'],
        exams: [es ? 'ECG seriado (0–6–12h)' : 'ECG seriado (0–6–12h)', es ? 'Troponina (0–3h)' : 'Troponina (0–3h)', 'RX tórax', es ? 'Glucemia' : 'Glicemia'],
        flags: [es ? 'Supradesnivel ST → cateterismo urgente' : 'Supradesnivelamento ST → cateterismo urgente',
                es ? 'Hipotensión → choque cardiogénico' : 'Hipotensão → choque cardiogênico'],
      ),

      // ── TEP ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'tep',
        label: es ? 'Tromboembolismo Pulmonar (TEP)' : 'Tromboembolismo Pulmonar (TEP)',
        protocolId: 'tep_agudo',
        keywords: ['tep', 'tromboembol pulm', 'embolia pulm', 'tvp', 'wells', 'd-dimero', 'angiotc torac'],
        exams: [es ? 'D-dímero (si baja probabilidad)' : 'D-dímero (se baixa probabilidade)', es ? 'AngioTC tórax' : 'AngioTC tórax', 'ECG (S1Q3T3)', 'Troponina', 'Score de Wells'],
        flags: [es ? 'Choque/hipotensión → trombolítico sistémico urgente' : 'Choque/hipotensão → trombolítico sistêmico urgente'],
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
      ),

      // ── Asma ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'asma',
        label: es ? 'Asma en Crisis / Broncoespasmo' : 'Asma em Crise / Broncoespasmo Agudo',
        protocolId: 'asma_grave',
        keywords: ['asma', 'broncoespas', 'sibilo', 'wheezing', 'peak flow', 'pfe ', 'broncodilatad'],
        exams: ['SpO2', es ? 'PFE (peak flow)' : 'PFE (peak flow)', es ? 'Gasometría si grave' : 'Gasometria se grave', es ? 'RX tórax si duda' : 'RX tórax se dúvida'],
        flags: [es ? 'Silencio auscultatorio + SpO2 <90% → riesgo de PCR inminente' : 'Silêncio auscultório + SpO2 <90% → risco de PCR iminente'],
      ),

      // ── CAD ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'cad',
        label: es ? 'Cetoacidosis Diabética (CAD)' : 'Cetoacidose Diabética (CAD)',
        protocolId: 'cad_shh',
        keywords: ['cetoacid', 'cad', 'hiperglicemi', 'cetona', 'acidose metabol', 'dka', 'ph baixo+diabet'],
        exams: [es ? 'Glucemia' : 'Glicemia', es ? 'Cetonemia/cetonuria' : 'Cetonemia/cetonúria', es ? 'Gasometría venosa' : 'Gasometria venosa', es ? 'Electrolitos (K+ urgente)' : 'Eletrólitos (K+ urgente)', 'BUN/Cr'],
        flags: [es ? 'K+ <3,3 → SUSPENDER insulina y reponer K+ primero' : 'K+ <3,3 → SUSPENDER insulina e repor K+ primeiro'],
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
      ),

      // ── Hipercalemia ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipercalemia',
        label: es ? 'Hipercalemia Grave' : 'Hipercalemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipercalemi', 'hiperpotass', 'k alt', 'hiperkalem', 'onda t apic', 'k+ elev'],
        exams: [es ? 'K+ sérico urgente' : 'K+ sérico urgente', 'ECG', 'Gasometria', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'K+ >6,5 o cambios ECG → Gluconato Ca2+ IV inmediato' : 'K+ >6,5 ou alteração ECG → Gluconato Ca2+ IV imediato',
                es ? 'Insulina + glucosa + bicarbonato + diálisis si refractario' : 'Insulina + glicose + bicarbonato + diálise se refratário'],
      ),

      // ── Hipopotassemia ────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipocalemia',
        label: es ? 'Hipopotasemia Grave' : 'Hipopotassemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipocalemi', 'hipopotass', 'k bai', 'hipokalem', 'k+ baixo'],
        exams: [es ? 'K+ sérico' : 'K+ sérico', es ? 'ECG (ondas U, QT largo)' : 'ECG (ondas U, QT longo)', 'Mg2+', 'Gasometria'],
        flags: [es ? 'K+ <2,5 o cambios ECG → reposición IV monitorizada' : 'K+ <2,5 ou alteração de ECG → reposição IV monitorada'],
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
      ),

      // ── Artrite Séptica ───────────────────────────────────────────────────
      _CliCondition(
        id: 'artrite_septica',
        label: es ? 'Artritis Séptica' : 'Artrite Séptica',
        protocolId: 'sepse',
        keywords: ['artrite septic', 'articulacao quente', 'monoartrite', 'artrite infec', 'artralgia febre', 'artritis septica'],
        exams: [es ? 'Artrocentesis + análisis líquido sinovial' : 'Artrocentese + análise do líquido sinovial', es ? 'Hemocultivos' : 'Hemoculturas', 'PCR/VHS', es ? 'Ácido úrico' : 'Ácido úrico'],
        flags: [es ? 'Artritis séptica → artrocentesis + ATB en <6h (S. aureus más común)' : 'Artrite séptica → artrocentese + ATB em <6h (S. aureus mais comum)'],
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
      ),
    ];

    // ── Calcular score de cada condição ──────────────────────────────────────
    int bestScore  = 0;
    _CliCondition? winner;

    for (final cond in conditions) {
      int score = 0;
      for (final kw in cond.keywords) {
        if (q.contains(kw)) score++;
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

      // 2c. Re-tentativa com qExpanded (histórico + msg atual)
      if (qHistory.isNotEmpty && qHistory.length > 5) {
        int bestExpScore = 0;
        for (final cond in conditions) {
          int sc = 0;
          for (final kw in cond.keywords) {
            if (qExpanded.contains(kw)) sc++;
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
            int bestCtx = 0;
            for (final cond in conditions) {
              int sc = 0;
              for (final kw in cond.keywords) {
                if (lastAI.contains(kw)) sc++;
              }
              if (sc > bestCtx) { bestCtx = sc; winner = cond; }
            }
            if (bestCtx == 0) winner = null;
          }
        }
      }

      // 2e. Fallback final
      if (winner == null) {
        if (_aiHistory.isNotEmpty) {
          return es
              ? 'Entiendo que es una pregunta de seguimiento. ¿Podrías especificar un poco más?\n\nEjemplos:\n• "¿Cuál es la dosis de [fármaco]?"\n• "¿Cuándo cardiovertir en FA?"\n• "¿Cuál es el protocolo de sepsis?"\n\n⚕ Apoyo educacional.'
              : 'Entendo que é uma pergunta de seguimento. Pode especificar um pouco mais?\n\nExemplos:\n• "Qual a dose de [fármaco]?"\n• "Quando cardioverter na FA?"\n• "Qual o protocolo de sepse?"\n\n⚕ Apoio educacional.';
        }
        return es
            ? 'Puedo ayudarte mejor con más detalles del caso clínico.\n\n**Sugerencias:**\n• Síntomas principales y tiempo de evolución\n• Signos vitales (PA, FC, SpO₂, temperatura)\n• Fármaco o condición específica\n\nEjemplos:\n• "FA con hipotensión — ¿cuál es la conducta?"\n• "¿Dosis de amiodarona en FA?"\n• "Sepsis — protocolo de antibióticos"\n\n⚕ Apoyo educacional.'
            : 'Posso ajudar melhor com mais detalhes do caso clínico.\n\n**Sugestões:**\n• Sintomas principais e tempo de evolução\n• Sinais vitais (PA, FC, SpO₂, temperatura)\n• Fármaco ou condição específica\n\nExemplos:\n• "FA com hipotensão — qual a conduta?"\n• "Dose de amiodarona na FA?"\n• "Sepse — protocolo de antibióticos"\n\n⚕ Apoio educacional.';
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 3 — RENDERIZAR RESPOSTA DA CONDIÇÃO VENCEDORA
    // ════════════════════════════════════════════════════════════════════════
    final buf = StringBuffer();

    // Cabeçalho: nome da condição
    buf.writeln('## ${winner!.label}');
    buf.writeln('');

    // Red flags — máx 3
    if (winner.flags.isNotEmpty) {
      buf.writeln(es ? '## Alertas:' : '## Alertas:');
      for (final f in winner.flags.take(3)) buf.writeln('  • $f');
      buf.writeln('');
    }

    // Protocolo clínico (conduta imediata) — se disponível
    ProtocolModel? proto;
    if (winner.protocolId != null) {
      try { proto = protocolsDatabase.firstWhere((p) => p.id == winner!.protocolId); }
      catch (_) {}
    }

    if (proto != null) {
      buf.writeln('## ${tDB(proto.title)}:');
      final actions = proto.getActions(_lang);
      for (int i = 0; i < actions.length && i < 5; i++) {
        buf.writeln('  ${actions[i]}');
      }
      if (actions.length > 5) {
        buf.writeln(_lang == 'es'
            ? '  → Ver protocolo completo en la pestaña Protocolos'
            : '  → Ver protocolo completo na aba Protocolos');
      }
      buf.writeln('');

      // Fármacos do protocolo
      final suggestedDrugs = proto.drugs.take(3)
          .map((id) { try { return drugsDatabase.firstWhere((d) => d.id == id); } catch (_) { return null; } })
          .whereType<DrugModel>().toList();

      if (suggestedDrugs.isNotEmpty && _patient.weight.isNotEmpty) {
        buf.writeln('## ${_lang == 'es' ? 'Dosis para este paciente:' : 'Dose para este paciente:'}');
        for (final drug in suggestedDrugs) {
          final dose   = calculateDose(drug);
          final alerts = dose.alerts.take(1).join(' | ');
          buf.writeln('  • ${drug.name}: ${dose.main}${alerts.isNotEmpty ? '  ⚠ $alerts' : ''}');
        }
        buf.writeln('');
      } else if (suggestedDrugs.isNotEmpty) {
        buf.writeln('${_lang == 'es' ? 'Fármacos' : 'Fármacos'}: ${suggestedDrugs.map((d) => d.name).join(', ')}');
        buf.writeln('');
      }
    } else if (winner.exams.isNotEmpty) {
      // Sem protocolo → mostra exames da condição
      buf.writeln(es ? '## Exámenes clave:' : '## Exames-chave:');
      for (final e in winner.exams.take(4)) buf.writeln('  • $e');
      buf.writeln('');
    }

    // Alertas contextuais de paciente
    final clcrVal = double.tryParse((clcr ?? '').replaceAll(',', '.'));
    if (clcrVal != null && clcrVal > 0 && clcrVal < 45) {
      buf.writeln('${clcrVal < 15 ? 'ALERTA' : 'Aten.'} ${_lang == 'es' ? 'ClCr $clcr — ajustar dosis renales' : 'ClCr $clcr — ajustar doses renais'}');
      buf.writeln('');
    }
    final ageVal = int.tryParse(_patient.age);
    if (ageVal != null && ageVal >= 75) {
      buf.writeln(_lang == 'es' ? 'Idoso: reducir dosis opioides/BZD, vigilar delirium.' : 'Idoso: reduzir dose opioides/BZD, vigilar delirium.');
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
  const _CliCondition({
    required this.id,
    required this.label,
    this.protocolId,
    required this.keywords,
    required this.exams,
    required this.flags,
  });
}
