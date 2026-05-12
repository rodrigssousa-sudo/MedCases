import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // ── Estado — IA Clínica ──────────────────────────────────────────────────
  String _openAiKey = '';
  // Histórico de conversa para contexto multi-turn (máx 10 pares)
  final List<Map<String, String>> _aiHistory = [];

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

    // 2️⃣ Sincroniza Firestore em background — não bloqueia a UI
    _syncFromFirestore(user.uid);

    // 3️⃣ Carrega chave OpenAI do Firestore em background (per-user)
    _loadAiKeyFromFirestore(user.uid);

    // 4️⃣ Carrega histórias públicas AQUI — token já está cacheado neste ponto.
    // No web, o initState da HistoryScreen rodava ANTES do token existir,
    // causando retorno silencioso de [] sem nem chegar na chamada REST.
    loadPublicHistories();
  }

  void clearUser() {
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
    // Limpa chave e histórico de IA ao fazer logout
    _openAiKey = '';
    _aiHistory.clear();
    notifyListeners();
  }

  void setFirebaseReady() {
    _firebaseReady = true;
    notifyListeners();
  }

  // ── Chave OpenAI — carregada do Firestore por UID ──────────────────────────
  Future<void> _loadAiKeyFromFirestore(String uid) async {
    try {
      final key = await FirestoreService.loadAiKey(uid);
      if (key.isNotEmpty) {
        _openAiKey = key;
        notifyListeners();
        // Também persiste no cache local como fallback offline
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', uid), key);
      }
    } catch (_) {
      // Sem rede: tenta cache local com prefixo do usuário
      try {
        final p = await SharedPreferences.getInstance();
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
        if (_openAiKey.isNotEmpty) notifyListeners();
      } catch (_) {}
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

  /// Retorna sumários dos protocolos cujos títulos/reconhecer contenham keywords da query
  List<String> _matchProtocols(String normalizedQuery) {
    final results = <String>[];
    for (final p in protocolsDatabase) {
      final title    = _normalize(tDB(p.title));
      final recognize = _normalize(tDB(p.recognize));
      // Verifica se alguma palavra significativa (>3 chars) da query aparece no protocolo
      final words = normalizedQuery.split(RegExp(r'\s+'))
          .where((w) => w.length > 3).toList();
      if (words.any((w) => title.contains(w) || recognize.contains(w))) {
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

  /// Constrói query expandida com contexto do histórico (últimas N msgs do usuário)
  String _expandedQuery(String currentInput, {int lastN = 5}) {
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    // Pega só as últimas N mensagens do usuário
    final tail = recentUserMsgs.length > lastN
        ? recentUserMsgs.sublist(recentUserMsgs.length - lastN)
        : recentUserMsgs;
    return '${tail.join(' ')} $currentInput'.trim();
  }

  /// Chamada principal — retorna resposta real da IA ou fallback local
  Future<String> buildAIAnswer(String input) async {
    // Se não tem chave → usa resposta local (rule-based) como fallback
    if (_openAiKey.isEmpty) {
      return _buildLocalAnswer(input);
    }

    // Expansão da query: usa histórico recente para melhorar o matching
    // Ex: usuário disse "paciente com FA" antes → "tiene FA" agora → match correto
    final expandedInput = _expandedQuery(input);
    final normalized = _normalize(expandedInput);
    final protocols  = _matchProtocols(normalized);
    final drugs      = _matchDrugs(normalized);

    final systemPrompt = AiService.buildClinicalSystemPrompt(
      lang: _lang,
      matchedProtocolSummaries: protocols,
      matchedDrugSummaries: drugs,
      patientAge: _patient.age.isNotEmpty ? _patient.age : null,
      patientSex: _patient.sex.isNotEmpty ? _patient.sex : null,
      patientWeight: _patient.weight.isNotEmpty ? _patient.weight : null,
      patientClcr: clcr,
      patientMedications: _patient.medications.isNotEmpty ? _patient.medications : null,
    );

    final result = await AiService.chat(
      apiKey: _openAiKey,
      userMessage: input,
      systemPrompt: systemPrompt,
      history: List.unmodifiable(_aiHistory),
    );

    if (result.isError) {
      // Erros específicos com mensagem amigável
      switch (result.errorCode) {
        case 'no_key':
          return _buildLocalAnswer(input);
        case 'invalid_key':
          return _lang == 'es'
              ? 'ERRO API: Clave inválida. Verifica la configuración de API Key en el chat.'
              : 'ERRO API: Chave inválida. Verifique a configuração de API Key no chat.';
        case 'quota':
          return _lang == 'es'
              ? 'Límite de uso de la API alcanzado. Revisa tu cuenta en platform.openai.com.'
              : 'Limite de uso da API atingido. Verifique sua conta em platform.openai.com.';
        case 'network':
          // Sem rede → fallback local silencioso
          return _buildLocalAnswer(input);
        default:
          return _buildLocalAnswer(input);
      }
    }

    // Adiciona ao histórico de conversa (contexto multi-turn)
    _aiHistory
      ..add({'role': 'user', 'content': input})
      ..add({'role': 'assistant', 'content': result.text});
    // Limita a 10 pares (20 mensagens) para não explodir tokens
    while (_aiHistory.length > 20) {
      _aiHistory.removeAt(0);
    }

    return result.text;
  }

  /// Resposta local (rule-based) — fallback quando não há chave ou sem rede
  String _buildLocalAnswer(String input) {
    final bool es = _lang == 'es';

    // ── Contexto acumulado do histórico (últimas 6 msgs do usuário) ───────────
    // Permite que perguntas de follow-up ("forma de administração", "tiene FA")
    // sejam respondidas com base no contexto já estabelecido na conversa.
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    final historyTail = recentUserMsgs.length > 6
        ? recentUserMsgs.sublist(recentUserMsgs.length - 6)
        : recentUserMsgs;
    final qHistory = _normalize(historyTail.join(' '));
    // Query expandida = histórico recente + mensagem atual
    final qExpanded = _normalize('$qHistory $input');
    // Query da mensagem atual
    final q = _normalize(input);

    final buf = StringBuffer();
    final suspected = <String>[];
    final protocolIds = <String>[];
    final examSuggestions = <String>[];
    final redFlags = <String>[];

    // ── Síndromes cardiovasculares ─────────────────────────────────────────
    if (_has(q, ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', 'sca'])) {
      suspected.add(es ? 'Síndrome Coronario Agudo (IAM/Angina Inestable)' : 'Síndrome Coronariana Aguda (IAM/Angina Instável)');
      protocolIds.add('iam_congestao');
      examSuggestions.addAll(es
        ? ['ECG seriado (0–6–12h)', 'Troponina (0–3h)', 'RX tórax', 'Glucemia']
        : ['ECG seriado (0–6–12h)', 'Troponina (0–3h)', 'RX tórax', 'Glicemia']);
      redFlags.addAll(es
        ? ['Supradesnivel ST → cateterismo urgente', 'Hipotensión → choque cardiogénico']
        : ['Supradesnivelamento ST → cateterismo urgente', 'Hipotensão → choque cardiogênico']);
    }
    if (_has(q, ['dispne', 'falta de ar', 'crepit', 'congest', 'edema pulm', 'ortopneia', 'ic ', 'insuf cardiac', 'b3', 'killip'])) {
      suspected.add('Insuficiência Cardíaca Descompensada / Edema Agudo de Pulmão');
      protocolIds.add('iam_congestao');
      examSuggestions.addAll(['BNP/NT-proBNP', 'RX tórax', 'Ecocardiograma', 'Eletrólitos']);
      redFlags.add('SpO2 <90% + esforço respiratório → VNI imediata');
    }
    if (_has(q, ['hipotens', 'choque', 'pele fria', 'oliguria', 'lactato', 'hipoperfus', 'extremid frias'])) {
      suspected.add('Choque (cardiogênico / séptico / hipovolêmico / obstrutivo)');
      protocolIds.add('choque_cardiogenico');
      examSuggestions.addAll(['Lactato arterial', 'Gasometria', 'ECG', 'Ecocardiograma beira-leito', 'Hemoculturas se febre']);
      redFlags.addAll(['PAM <65 → vasopressor imediato', 'Lactato >4 → reanimação agressiva']);
    }
    if (_has(q, ['fa ', 'fibrilac atrial', 'fibril atri', 'auricular', 'rr irregular'])) {
      suspected.add('Fibrilação Atrial');
      protocolIds.add('fa_aguda');
      examSuggestions.addAll(['ECG 12 derivações', 'TSH', 'Eletrólitos', 'Ecocardiograma', 'Coagulação']);
      redFlags.add('FC >150 com instabilidade → cardioversão elétrica imediata');
    }
    if (_has(q, ['dissecc', 'disseçao aort', 'dor torn', 'assimetr', 'interescap'])) {
      suspected.add('Dissecção Aórtica Aguda');
      protocolIds.add('crise_hipertensiva');
      examSuggestions.addAll(['AngioTC aorta urgente', 'RX tórax', 'ECG', 'PA nos 2 braços']);
      redFlags.addAll(['NÃO anticoagular sem confirmar diagnóstico', 'Controle FC+PA imediato: meta PAS <120 + FC <60']);
    }

    // ── Arritmias ──────────────────────────────────────────────────────────
    if (_has(q, ['taquic', 'palpit', 'qrs estrei', 'tpsv', 'arritm supravent'])) {
      suspected.add('Taquiarritmia Supraventricular (TPSV / FA / Flutter)');
      protocolIds.add('tpsv');
      examSuggestions.addAll(['ECG 12 derivações', 'Eletrólitos (K+, Mg2+)', 'TSH']);
    }
    if (_has(q, ['fv ', 'fibrilac ventr', 'tv ', 'taquic ventr', 'pcr', 'parada cardiac', 'sem pulso'])) {
      suspected.add('Parada Cardiorrespiratória / FV / TV sem pulso');
      protocolIds.add('pcr_adulto');
      examSuggestions.addAll(['Monitor/desfibrilador', 'Gasometria pós-ROSC', 'ECG pós-ROSC', 'Glicemia']);
      redFlags.add('ACLS imediato: RCP de alta qualidade + desfibrilação');
    }

    // ── Neurológicos ──────────────────────────────────────────────────────
    if (_has(q, ['avc', 'acidente vasc', 'hemiplegi', 'deficit focal', 'afasia', 'hemiparesia', 'desvio boca'])) {
      suspected.add('AVC (Isquêmico ou Hemorrágico)');
      protocolIds.add('avc_isquemico');
      examSuggestions.addAll(['TC crânio URGENTE (sem contraste)', 'Glicemia capilar', 'Coagulação', 'ECG', 'PA']);
      redFlags.addAll(['Janela trombolítica: <4,5h', 'Hipoglicemia mimetiza AVC — checar glicemia sempre', 'Hipertensão grave: tratar apenas se PAS >220 (sem trombolítico)']);
    }
    if (_has(q, ['hemorrag intracran', 'hemorrag cerebr', 'sangr cerebr', 'hematoma subdur', 'hematoma extradur'])) {
      suspected.add('Hemorragia Intracraniana');
      protocolIds.add('avc_hemorragico');
      examSuggestions.addAll(['TC crânio urgente', 'Coagulação completa', 'Plaquetas']);
      redFlags.addAll(['CONTRAINDICADO trombolítico e anticoagulantes', 'Reverter anticoagulação imediatamente']);
    }
    if (_has(q, ['convuls', 'epileps', 'status epilep', 'crise convuls', 'crise epilep'])) {
      suspected.add('Status Epilepticus / Convulsão');
      protocolIds.add('status_epilepticus');
      examSuggestions.addAll(['Glicemia', 'Eletrólitos (Na+, Mg2+, Ca2+)', 'TC crânio', 'EEG se status refratário']);
      redFlags.add('Crise >5 min → benzodiazepínico IMEDIATO');
    }

    // ── Cefaleia — raciocínio em 2 níveis ────────────────────────────────
    // Nível 1: keyword genérico → hipótese comum (enxaqueca/tensional/viral)
    // Nível 2: qualificador de gravidade → escala para HSA/meningite
    if (_has(q, ['cefal', 'dor de cabeca', 'dor cabeca', 'dor de cabe'])) {
      // Qualificadores que indicam alto risco neurológico
      final hasHighRiskHeadache = _has(q, [
        'trovoada', 'pior cefaleia', 'pior dor', 'inicio subito',
        'rigidez', 'meningismo', 'petequi', 'nucal',
        'inconsciente', 'perda de consciencia',
      ]);
      // Combinação febre + cefaleia (suspeita de meningite)
      final hasFeverHeadache = _has(q, ['febre']) &&
          _has(q, ['cefal', 'dor de cabeca', 'dor cabeca']);
      // Sinal neurológico focal associado
      final hasFocalSign = _has(q, [
        'deficit focal', 'afasia', 'hemiplegi', 'hemiparesia',
        'glasgow', 'confusao', 'alteracao de consciencia',
      ]);

      if (hasHighRiskHeadache || hasFocalSign) {
        suspected.add('Cefaleia de alto risco — excluir HSA / Meningite');
        protocolIds.add('avc_hemorragico');
        examSuggestions.addAll(['TC crânio sem contraste (excluir HSA)', 'Punção lombar se TC negativa', 'Hemoculturas + PCR se febre', 'Hemograma']);
        redFlags.addAll(['"Pior cefaleia da vida" ou início súbito → excluir HSA urgente', 'Déficit focal + cefaleia → descartar AVC/hemorragia']);
      } else if (hasFeverHeadache) {
        suspected.add('Cefaleia com febre — investigar: viral, bacteriana, meningite');
        examSuggestions.addAll(['Temperatura', 'Hemograma', 'PCR', 'Avaliar rigidez nucal no exame físico']);
        redFlags.add('Rigidez nucal + febre + cefaleia → suspeitar meningite e acionar avaliação urgente');
      } else {
        // Sem qualificadores → hipóteses comuns, sem protocolo de emergência
        suspected.add('Cefaleia — causas comuns: enxaqueca, tensional, viral, hipertensão');
        examSuggestions.addAll(['PA (descartar crise hipertensiva)', 'Temperatura', 'Intensidade (EVA 0–10) e padrão temporal']);
        redFlags.add('Se início súbito "em trovoada" ou pior da vida → avaliar urgência');
      }
    }

    // ── Náusea / Vômito — raciocínio em 2 níveis ─────────────────────────
    // Nível 1: sintoma isolado ou com cefaleia simples → causas comuns
    // Nível 2: combinação com red flags específicos → deixa bloco especializado agir
    if (_has(q, ['nause', 'vomit', 'enjoo', 'emese'])) {
      final hasAbdominalEmergency = _has(q, [
        'dor abdom', 'rigidez abdom', 'defesa abdom', 'peritonite',
        'melena', 'hematemes', 'sangue nas fezes', 'hemorrag digest',
      ]);
      final hasNeuroGravity = _has(q, [
        'trovoada', 'pior cefaleia', 'rigidez nuca', 'meningismo',
        'petequi', 'glasgow', 'perda de consciencia', 'deficit focal',
        'afasia', 'hemiplegi', 'hemiparesia',
      ]);
      final hasCardioGravity = _has(q, [
        'dor torac', 'dor no peito', 'infarto', 'sudorese fria',
        'hipotens', 'choque', 'sem pulso',
      ]);
      final hasMetabolicGravity = _has(q, [
        'cetoacid', 'hiperglicemi', 'hipoglicemi', 'insuf renal',
        'anuria', 'uremia',
      ]);

      if (!hasAbdominalEmergency && !hasNeuroGravity && !hasCardioGravity && !hasMetabolicGravity) {
        suspected.add(es
          ? 'Síndrome emética — causas comunes: gastroenteritis viral, alimentaria, migraña, medicamentosa'
          : 'Síndrome emética — causas comuns: gastroenterite viral, alimentar, enxaqueca, medicamentosa');
        examSuggestions.addAll(es
          ? [
              'Temperatura (fiebre sugiere causa infecciosa)',
              'PA y FC (deshidratación / hipotensión ortostática)',
              'Glucemia capilar',
              'Evaluar signos de deshidratación (turgencia, mucosas)',
            ]
          : [
              'Temperatura (febre sugere causa infecciosa)',
              'PA e FC (desidratação / hipotensão ortostática)',
              'Glicemia capilar',
              'Avaliar sinais de desidratação (turgor, mucosas)',
            ]);
        redFlags.add(es
          ? 'Si dolor abdominal intenso, sangrado, rigidez o alteración de conciencia → urgencia'
          : 'Se dor abdominal intensa, sangramento, rigidez ou rebaixamento → urgência');
      }
    }

    // ── Respiratórios ──────────────────────────────────────────────────────
    if (_has(q, ['asma', 'broncoespas', 'sibilo', 'wheezing'])) {
      suspected.add('Asma em Crise / Broncoespasmo Agudo');
      protocolIds.add('asma_grave');
      examSuggestions.addAll(['SpO2', 'PFE (peak flow)', 'Gasometria se grave', 'RX tórax se dúvida']);
      redFlags.add('Silêncio auscultório + SpO2 <90% → risco de PCR iminente');
    }
    if (_has(q, ['dpoc', 'doença pulm obstr', 'enfisema', 'bronquite cronica', 'exacerbac pulm'])) {
      suspected.add('DPOC em Exacerbação Aguda');
      protocolIds.add('dpoc_exacerbacao');
      examSuggestions.addAll(['Gasometria arterial', 'RX tórax', 'SpO2', 'Hemograma', 'PCR']);
      redFlags.addAll(['O2 CONTROLADO: SpO2 alvo 88–92%', 'pH <7,35 + PaCO2 elevado → VNI imediata']);
    }
    if (_has(q, ['tep', 'tromboembol pulm', 'embolia pulm', 'dispneia sub', 'taquic+dispneia', 'tvp'])) {
      suspected.add('Tromboembolismo Pulmonar (TEP)');
      protocolIds.add('tep_agudo');
      examSuggestions.addAll(['D-dímero (se baixa probabilidade)', 'AngioTC tórax', 'ECG (S1Q3T3)', 'Troponina', 'BNP/Echo', 'Score de Wells']);
      redFlags.add('Choque/hipotensão → trombolítico sistêmico urgente');
    }
    if (_has(q, ['pneumon', 'infeccao pulm', 'infiltrado', 'consolidac', 'tosse+febre+dispn'])) {
      suspected.add('Pneumonia Adquirida na Comunidade (PAC) / Nosocomial');
      protocolIds.add('sepse');
      examSuggestions.addAll(['RX tórax', 'Hemoculturas (2 pares)', 'Hemograma', 'PCR', 'Ureia', 'Score PSI/PORT ou CURB-65']);
      redFlags.add('PSI ≥V ou CURB-65 ≥3 → hospitalização / UTI');
    }

    // ── Sepse / Infecção ──────────────────────────────────────────────────
    if (_has(q, ['sepse', 'seps', 'septic', 'bacterem', 'infec grave', 'choque septic'])) {
      suspected.add('Sepse / Choque Séptico');
      protocolIds.add('sepse');
      examSuggestions.addAll(['Lactato', 'Hemoculturas (2 pares)', 'Uroculturas', 'PCR/Procalcitonina', 'Hemograma', 'Função renal', 'Gasometria']);
      redFlags.addAll(['Antibiótico em <1 HORA', 'Lactato >4 → 30 mL/kg SF', 'Vasopressor se PAM <65 após volume']);
    }
    if (_has(q, ['meningite', 'encefalite', 'rigidez nuca', 'kernig', 'brudzinski', 'confusao+febre'])) {
      suspected.add('Meningite / Encefalite Bacteriana');
      protocolIds.add('sepse');
      examSuggestions.addAll(['TC crânio (antes da PL se focal)', 'Punção lombar', 'Hemoculturas', 'Glicemia', 'PCR']);
      redFlags.addAll(['ATB IMEDIATO — não atrasar por PL', 'Dexametasona 0,15 mg/kg IV antes ou junto ao ATB']);
    }

    // ── Endócrinos / Metabólicos ───────────────────────────────────────────
    if (_has(q, ['cetoacid', 'cad', 'glicos alt', 'hiperglicemi', 'cetona', 'vomit+diabetes'])) {
      suspected.add('Cetoacidose Diabética (CAD)');
      protocolIds.add('cad_shh');
      examSuggestions.addAll(['Glicemia', 'Cetonemia/cetonúria', 'Gasometria venosa', 'Eletrólitos (K+ urgente)', 'BUN/Cr']);
      redFlags.add('K+ <3,3 → SUSPENDER insulina e repor K+ primeiro');
    }
    if (_has(q, ['hipoglicemi', 'glicemia bai', 'confusao+diabetes', 'sudorese fria', 'tremor+diabetes'])) {
      suspected.add('Hipoglicemia Grave');
      protocolIds.add('cad_shh');
      examSuggestions.addAll(['Glicemia capilar URGENTE', 'Glicemia venosa']);
      redFlags.addAll(['Glicemia <60 → 50 mL glicose 50% IV imediato', 'Sem acesso IV → glucagon 1 mg IM/SC']);
    }
    if (_has(q, ['hipocalemi', 'hipopotass', 'k bai', 'hipokalem', 'fraqueza muscul+eletroli'])) {
      suspected.add('Hipopotassemia Grave');
      protocolIds.add('cad_shh');
      examSuggestions.addAll(['K+ sérico', 'ECG (ondas U, QT longo)', 'Mg2+', 'Gasometria']);
      redFlags.add('K+ <2,5 ou alteração de ECG → reposição IV monitorada');
    }
    if (_has(q, ['hipercalemi', 'hiperpotass', 'k alt', 'hiperkalem', 'ecg+onda t apic'])) {
      suspected.add('Hipercalemia Grave');
      protocolIds.add('cad_shh');
      examSuggestions.addAll(['K+ sérico urgente', 'ECG', 'Gasometria', 'Função renal']);
      redFlags.addAll(['K+ >6,5 ou alteração ECG → Gluconato de Ca2+ IV imediato', 'Insulina + glicose + bicarbonato + diálise se refratário']);
    }
    if (_has(q, ['crise tireo', 'tempestade tireo', 'hipotireoidismo grave', 'mixedema', 'tirotoxicos'])) {
      suspected.add('Crise Tireotóxica / Mixedema Grave');
      protocolIds.add('sepse');
      examSuggestions.addAll(['TSH', 'T4 livre', 'T3', 'Hemograma', 'Função hepática']);
      redFlags.add('Crise tireotóxica → UTI imediata (mortalidade alta)');
    }

    // ── Renais ─────────────────────────────────────────────────────────────
    if (_has(q, ['insuf renal aguda', 'ira', 'oliguria', 'anuria', 'creatinina elev', 'uremia'])) {
      suspected.add('Insuficiência Renal Aguda (IRA)');
      protocolIds.add('cad_shh');
      examSuggestions.addAll(['Creatinina/Ureia seriadas', 'EAS/uroculturas', 'Eletrólitos', 'Eco renal', 'ANCA/anti-MBG se glomerulite']);
      redFlags.addAll(['K+ >6 ou oligúria refratária → diálise de urgência', 'Excluir pré-renal (volume) e obstrutivo (eco) antes de tratar intrínseco']);
    }

    // ── Gastroenterológicos ────────────────────────────────────────────────
    if (_has(q, ['hematemes', 'hemorrag digest', 'melena', 'hamatoquezia', 'sangr gi', 'ulcera sangr'])) {
      suspected.add('Hemorragia Digestiva Alta / Varicosa');
      protocolIds.add('hda_varizeal');
      examSuggestions.addAll(['Hemograma', 'Coagulação', 'Grupo sanguíneo', 'Função renal', 'EDA urgente']);
      redFlags.addAll(['Instabilidade → 2 acessos calibrosos + SF imediato', 'Hb alvo 7–8 g/dL (transfusão restritiva)']);
    }
    if (_has(q, ['dor abdom', 'abdome agudo', 'peritonite', 'rigidez abd', 'defesa abdom', 'board-like'])) {
      suspected.add('Abdome Agudo / Peritonite');
      protocolIds.add('sepse');
      examSuggestions.addAll(['RX abdome', 'TC abdome+pelve c/contraste', 'Hemograma', 'Lipase/amilase', 'PCR', 'Urina I']);
      redFlags.add('Sinais peritoneais + instabilidade → cirurgia de emergência');
    }
    if (_has(q, ['pancreatite', 'dor epigast irrad dorso', 'lipase elev', 'amilase elev'])) {
      suspected.add('Pancreatite Aguda');
      protocolIds.add('sepse');
      examSuggestions.addAll(['Lipase/amilase', 'TC abdome (se grave/dúvida)', 'Eletrólitos', 'Cálcio', 'Glicemia', 'Score BISAP/APACHE']);
      redFlags.add('Score BISAP ≥3 ou CTSI elevado → UTI (pancreatite grave)');
    }

    // ── Psiquiátrico / Outras ──────────────────────────────────────────────
    if (_has(q, ['delirium', 'confusao aguda', 'agitac', 'rebaixamento conscien', 'glasgow baixo'])) {
      suspected.add('Delirium / Rebaixamento do Nível de Consciência');
      protocolIds.add('status_epilepticus');
      examSuggestions.addAll(['Glicemia capilar', 'TC crânio', 'Eletrólitos', 'Função renal/hepática', 'Hemoculturas', 'Gasometria', 'Revisão de medicamentos']);
      redFlags.addAll(['Excluir: hipoglicemia, AVC, meningite, IRA, intoxicação', 'Glasgow <8 → proteger via aérea']);
    }
    if (_has(q, ['intoxicac', 'overdose', 'envenenam', 'ingestao', 'organofosf', 'benzodiaz+depressao resp'])) {
      suspected.add('Intoxicação / Overdose');
      protocolIds.add('pcr_adulto');
      examSuggestions.addAll(['Toxicológico urinário', 'Gasometria', 'Eletrólitos', 'ECG (QT longo, arritmia)', 'Paracetamol/salicilato', 'Glicemia']);
      redFlags.addAll(['Contato imediato com Centro de Informação Toxicológica', 'Antídotos específicos conforme agente (naloxona, flumazenil, N-acetilcisteína, atropina)']);
    }
    if (_has(q, ['crise hipert', 'pa muito alta', 'pa >180', 'emergencia hiperten', 'encefalopatia hiperten'])) {
      suspected.add('Crise Hipertensiva (Urgência / Emergência)');
      protocolIds.add('crise_hipertensiva');
      examSuggestions.addAll(['PA em ambos os braços', 'ECG', 'Fundo de olho', 'Creatinina/ureia', 'EAS', 'TC crânio se sintomas neurológicos']);
      redFlags.addAll(['Encefalopatia + PA >180 → emergência (redução controlada IV)', 'NÃO reduzir PA >25% na 1ª hora']);
    }

    // ── Cardiologia adicional ──────────────────────────────────────────────
    if (_has(q, ['fa ', 'fibrilac atrial', 'fibril atri', 'auricular', 'rr irregular', 'flutter', 'fibrilacao'])) {
      suspected.add('Fibrilação Atrial / Flutter Atrial');
      protocolIds.add('fa_aguda');
      examSuggestions.addAll(['ECG 12 derivações', 'TSH', 'Eletrólitos (K+, Mg2+)', 'Ecocardiograma', 'Coagulação', 'Score CHA₂DS₂-VASc']);
      redFlags.addAll(['FC > 150 + instabilidade hemodinâmica → cardioversão elétrica imediata', 'FA > 48h sem anticoagulação → risco de AVC por trombo']);
    }
    if (_has(q, ['ic ', 'insuf cardiac', 'ortopneia', 'edema pulmonar', 'crepitac', 'dispne', 'bnp', 'fej', 'frac ejec'])) {
      suspected.add('Insuficiência Cardíaca Descompensada / Edema Agudo de Pulmão');
      protocolIds.add('iam_congestao');
      examSuggestions.addAll(['BNP/NT-proBNP', 'RX tórax', 'Ecocardiograma', 'Eletrólitos', 'Função renal', 'Hemograma']);
      redFlags.addAll(['SpO2 < 90% + esforço respiratório → VNI (CPAP/BIPAP) imediata', 'Hipotensão + IC → choque cardiogênico: cuidado com diurético agressivo']);
    }
    if (_has(q, ['crise hipert', 'pa muito alta', 'pa > 180', 'emergencia hiperten', 'encefalopatia hiperten', 'urgencia hiperten', 'hipertensao grave'])) {
      suspected.add('Crise Hipertensiva (Urgência / Emergência)');
      protocolIds.add('crise_hipertensiva');
      examSuggestions.addAll(['PA em ambos os braços', 'ECG', 'Fundo de olho', 'Creatinina/ureia', 'EAS', 'TC crânio se sintomas neurológicos']);
      redFlags.addAll(['Encefalopatia/AVC/IAM/IRA + PA > 180 → emergência: redução IV controlada', 'NÃO reduzir PA > 25% na 1ª hora — risco de AVC isquêmico por hipoperfusão']);
    }

    // ── Hematologia / Coagulação ───────────────────────────────────────────
    if (_has(q, ['hematemes', 'hemorrag digest', 'melena', 'hematoquezia', 'sangr gi', 'ulcera sangr', 'varizes esof'])) {
      suspected.add('Hemorragia Digestiva Alta (HDA) — Ulcerosa / Varicosa');
      protocolIds.add('hda_varizeal');
      examSuggestions.addAll(['Hemograma (Hb, Ht)', 'Coagulação (TP, TTPA)', 'Tipagem sanguínea', 'Função renal', 'EDA urgente em < 24h', 'Score de Blatchford']);
      redFlags.addAll(['PA sistólica < 100 + FC > 100 → 2 acessos calibrosos + SF imediato', 'Hb alvo pós-transfusão 7–8 g/dL (transfusão restritiva)', 'Cirrose + HDA → octreotida + ATB profilático + Terlipressina']);
    }
    if (_has(q, ['anticoagulac', 'sangramento ativo', 'heparina reverter', 'varfarina', 'warfarin', 'reverter anticoag'])) {
      suspected.add('Sangramento em Uso de Anticoagulante / Reversão de Anticoagulação');
      protocolIds.add('hda_varizeal');
      examSuggestions.addAll(['INR/TP/TTPA', 'Hemograma', 'Tipagem', 'Função renal']);
      redFlags.addAll(['Varfarina + sangramento grave → vitamina K 10 mg EV + CCP (4 fatores)', 'Heparina → protamina 1 mg / 100 UI heparina EV', 'DOAC → agentes específicos: idarucizumabe (dabigatrana), andexanete alfa (rivaroxabana/apixabana)']);
    }

    // ── Dor abdominal / Cirúrgico ──────────────────────────────────────────
    if (_has(q, ['dor abdom', 'abdome agudo', 'peritonite', 'rigidez abd', 'defesa abdom', 'apendicite', 'colecistite', 'obstru intestinal'])) {
      suspected.add('Abdome Agudo / Peritonite / Síndrome Abdominal Cirúrgica');
      protocolIds.add('sepse');
      examSuggestions.addAll(['RX abdome em pé', 'TC abdome+pelve com contraste', 'Hemograma', 'PCR', 'Lipase/amilase', 'Ureia/Cr', 'Urina I']);
      redFlags.addAll(['Sinais peritoneais + instabilidade → cirurgia de emergência', 'Pneumoperitônio no RX → perfuração visceral: cirurgia imediata']);
    }
    if (_has(q, ['pancreatite', 'dor epigast irrad dorso', 'lipase elev', 'amilase elev', 'pancreat'])) {
      suspected.add('Pancreatite Aguda');
      protocolIds.add('sepse');
      examSuggestions.addAll(['Lipase (> 3× LSN diagnóstico)', 'TC abdome (Balthazar/CTSI — se grave ou dúvida)', 'Eletrólitos', 'Cálcio', 'Glicemia', 'TGO/TGP/FA', 'Score BISAP']);
      redFlags.addAll(['Score BISAP ≥ 3 ou APACHE II alto → UTI (pancreatite grave)', 'Necroinfeção: febre + piora clínica após 48–72h → TC + ATB (imipenem/meropeném)']);
    }

    // ── Delirium / Intoxicação / Psiquiátrico ──────────────────────────────
    if (_has(q, ['delirium', 'confusao aguda', 'agitac', 'rebaixamento conscien', 'glasgow baixo', 'confusao mental'])) {
      suspected.add('Delirium / Rebaixamento de Consciência (investigar causa base)');
      protocolIds.add('status_epilepticus');
      examSuggestions.addAll(['Glicemia capilar URGENTE', 'TC crânio', 'Eletrólitos (Na+, K+, Mg2+, Ca2+)', 'Função renal e hepática', 'Hemoculturas + Urina I', 'Gasometria', 'Revisão de medicamentos (polifarmácia)']);
      redFlags.addAll(['Excluir SEMPRE: hipoglicemia, AVC, meningite, IRA, intoxicação', 'Glasgow ≤ 8 → proteger via aérea (IOT)', 'CAM positivo + idoso → delirium: tratar causa base, evitar haloperidol em QT longo']);
    }
    if (_has(q, ['intoxicac', 'overdose', 'envenenam', 'ingestao', 'organofosf', 'benzodiaz+depressao resp', 'intoxicacao'])) {
      suspected.add('Intoxicação Exógena / Overdose');
      protocolIds.add('pcr_adulto');
      examSuggestions.addAll(['Toxicológico urinário', 'Gasometria', 'Eletrólitos', 'ECG (QT longo, arritmia)', 'Paracetamol e salicilato séricos', 'Glicemia', 'Função renal e hepática']);
      redFlags.addAll(['Contato imediato: Centro de Informação Toxicológica (0800 722 6001)', 'Antídotos: naloxona (opioides), flumazenil (BZD), N-acetilcisteína (paracetamol), atropina (organofosforados)', 'Carvão ativado 1 g/kg VO se < 1h da ingestão e via aérea protegida']);
    }

    // ── Reumatologia / MSK ─────────────────────────────────────────────────
    if (_has(q, ['artrite septic', 'articulacao quente', 'monoartrite', 'artrite infec', 'artralgia febre'])) {
      suspected.add('Artrite Séptica / Artropatia Inflamatória Aguda');
      protocolIds.add('sepse');
      examSuggestions.addAll(['Artrocentese + análise do líquido sinovial', 'Hemoculturas', 'PCR/VHS', 'Hemograma', 'Ácido úrico', 'Rx articulação']);
      redFlags.add('Artrite séptica → artrocentese + ATB em < 6h (S. aureus mais comum)');
    }

    // ── Dermatologia / Lesão de pele ───────────────────────────────────────
    if (_has(q, ['eritroderm', 'fasciite necros', 'steven johnson', 'ten', 'necrolise epider', 'celulite extensa'])) {
      suspected.add('Dermatose Grave / Fasciíte Necrosante / Síndrome de Stevens-Johnson');
      protocolIds.add('sepse');
      examSuggestions.addAll(['Hemograma', 'PCR', 'Creatinina', 'Coagulação', 'Hemocultura', 'Biopsia se necessário']);
      redFlags.addAll(['Fasciíte necrosante → cirurgia de desbridamento URGENTE + ATB broad-spectrum', 'SJS/TEN → UTI, suspender medicamento causador, cuidados como queimado']);
    }

    // ── Obstétrica / Ginecológica ──────────────────────────────────────────
    if (_has(q, ['eclamps', 'pre-eclamps', 'pressao gestac', 'gestante hiperten', 'convulsao gravida', 'hellp'])) {
      suspected.add('Pré-eclâmpsia Grave / Eclâmpsia / Síndrome HELLP');
      protocolIds.add('crise_hipertensiva');
      examSuggestions.addAll(['PA seriada', 'Proteinúria 24h ou razão Pr/Cr', 'Hemograma + plaquetas', 'TGO/TGP', 'LDH', 'Creatinina', 'Ácido úrico']);
      redFlags.addAll(['PA ≥ 160/110 em gestante → anti-hipertensivo imediato (hidralazina/nifedipina)', 'Convulsão → sulfato de magnésio 4–6 g EV (ataque) + 1–2 g/h manutenção', 'HELLP → parto imediato se ≥ 34 semanas']);
    }

    // ════════════════════════════════════════════════════════════════════════
    // ── INTELIGÊNCIA CONTEXTUAL (quando suspected ainda está vazio) ─────────
    // Antes de pedir mais contexto, tenta extrair informação útil de:
    //   1. Perguntas de farmacologia (via, dose, mecanismo, interação, adversos)
    //   2. Re-tentativa com qExpanded (histórico + msg atual)
    //   3. Follow-up clínico genérico quando há contexto no histórico
    // ════════════════════════════════════════════════════════════════════════
    if (suspected.isEmpty) {

      // ── 1. PERGUNTAS DE FARMACOLOGIA DIRETA ────────────────────────────
      // Detecta intenção: "via de administração", "dose", "mecanismo",
      // "efeito adverso", "interação", "contraindicação", "como dar", etc.
      final isPharmaQuestion = _has(qExpanded, [
        'via de admin', 'forma de admin', 'via admin', 'como admin',
        'como dar', 'como usar', 'modo de usar', 'modo de admin',
        'rota de admin', 'via de uso',
        'dose ', 'dosagem', 'posolog', 'dose maxima', 'dose minima',
        'dose inicial', 'dose de ataque', 'dose de manutenc',
        'mecanismo', 'mecanismo de acao', 'como funciona', 'por que usar',
        'efeito adverso', 'efeito colateral', 'reacao adversa',
        'evento adverso', 'efeitos', 'toxicidade',
        'interacao', 'interacoes', 'interage', 'compativel',
        'contraindicacao', 'contraindicado', 'nao usar', 'quando nao',
        'indicacao', 'indicado para', 'para que serve', 'quando usar',
        'alerta', 'cuidado', 'atencao renal', 'ajuste renal',
        'idoso', 'gestante', 'grávida', 'pediatr',
        // espanhol
        'via de administracion', 'forma de administracion', 'como administrar',
        'dosis', 'posologia', 'mecanismo de accion', 'efecto adverso',
        'efectos secundarios', 'interaccion', 'contraindicacion',
        'para que sirve', 'cuando usar', 'alerta renal',
      ]);

      if (isPharmaQuestion) {
        // Busca fármacos mencionados na query expandida (histórico + atual)
        final matchedDrugs = _matchDrugs(_normalize(qExpanded));
        if (matchedDrugs.isNotEmpty) {
          // Determina o tipo de pergunta para resposta focada
          final askingVia   = _has(qExpanded, ['via ', 'via de', 'forma de admin', 'como admin', 'como dar', 'rota', 'modo de', 'administracion']);
          final askingDose  = _has(qExpanded, ['dose', 'dosagem', 'posolog', 'dosis']);
          final askingMech  = _has(qExpanded, ['mecanismo', 'como funciona', 'por que', 'mecanismo de acao', 'mecanismo de accion']);
          final askingAdv   = _has(qExpanded, ['adverso', 'colateral', 'reacao', 'toxicidad', 'efectos sec', 'efeito']);
          final askingInter = _has(qExpanded, ['interacao', 'interaccion', 'interage', 'compativel']);
          final askingCI    = _has(qExpanded, ['contraindicacao', 'contraindicado', 'nao usar', 'contraindicacion']);
          final askingInd   = _has(qExpanded, ['indicacao', 'indicado', 'para que', 'quando usar', 'sirve', 'indicacion']);

          buf.writeln(es ? '## Información farmacológica:' : '## Informações farmacológicas:');
          buf.writeln('');

          for (final drug in drugsDatabase) {
            final dName = _normalize(drug.name);
            // Verifica se este fármaco foi mencionado na query expandida
            final words = qExpanded.split(RegExp(r'\s+')).where((w) => w.length > 3);
            final isMatch = words.any((w) => dName.contains(w));
            if (!isMatch) continue;

            buf.writeln('### ${drug.name}');

            if (askingVia || (!askingDose && !askingMech && !askingAdv && !askingInter && !askingCI && !askingInd)) {
              // drug.route é String direta (não Map)
              if (drug.route.isNotEmpty) {
                buf.writeln('  **${es ? "Vía" : "Via"}:** ${drug.route}');
              }
            }
            if (askingDose || (!askingVia && !askingMech && !askingAdv && !askingInter && !askingCI && !askingInd)) {
              final fd = drug.getField(drug.fixedDose, _lang);
              if (fd.isNotEmpty) {
                buf.writeln('  **${es ? "Dosis habitual" : "Dose habitual"}:** $fd');
              }
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
              if (mech.isNotEmpty) buf.writeln('  **${es ? "Mecanismo" : "Mecanismo"}:** $mech');
            }
            if (askingAdv) {
              // adverse usa getAdverse() que retorna List<String>
              final advList = drug.getAdverse(_lang);
              if (advList.isNotEmpty) {
                final advText = advList.take(5).join(', ');
                buf.writeln('  **${es ? "Efectos adversos" : "Efeitos adversos"}:** $advText');
              }
            }
            if (askingCI) {
              final warn = drug.getField(drug.warning, _lang);
              if (warn.isNotEmpty) buf.writeln('  **${es ? "Contraindicaciones / Alertas" : "Contraindicações / Alertas"}:** ${warn.length > 200 ? warn.substring(0, 200) + '...' : warn}');
            }
            if (askingInd) {
              final cls = drug.getField(drug.className, _lang);
              if (cls.isNotEmpty) buf.writeln('  **${es ? "Clase / Uso" : "Classe / Uso"}:** $cls');
            }
            if (askingInter) {
              // Busca interações do fármaco no banco via checkInteractions
              final interList = DrugInteractionService.checkInteractions(
                selectedDrugNames: [drug.name],
                patientMedicationsText: _patient.medications,
              );
              if (interList.isNotEmpty) {
                buf.writeln('  **${es ? "Interacciones relevantes" : "Interações relevantes"}:**');
                for (final inter in interList.take(4)) {
                  final sev = inter.severity == InteractionSeverity.contraindicated
                      ? '⛔ ${es ? "Contraindicado" : "Contraindicado"}'
                      : inter.severity == InteractionSeverity.major
                          ? '🔴 ${es ? "Mayor" : "Maior"}'
                          : inter.severity == InteractionSeverity.moderate
                              ? '🟠 ${es ? "Moderada" : "Moderada"}'
                              : '🟡 ${es ? "Menor/Monitorar" : "Menor/Monitorar"}';
                  final effectText = inter.effect;
                  buf.writeln('    $sev — ${inter.drug1} + ${inter.drug2}: ${effectText.length > 100 ? effectText.substring(0, 100) + "..." : effectText}');
                }
              } else {
                buf.writeln('  ${es ? "No se encontraron interacciones registradas con los medicamentos actuales." : "Nenhuma interação registrada com os medicamentos atuais."}');
              }
            }

            // Alerta renal se ClCr baixo
            final clcrVal = double.tryParse((clcr ?? '').replaceAll(',', '.'));
            if (clcrVal != null && clcrVal > 0 && clcrVal < 45) {
              final renalAlert = drug.getField(drug.renalAlert, _lang);
              if (renalAlert.isNotEmpty) {
                buf.writeln('  ⚠ **${es ? "Alerta renal (ClCr $clcr)" : "Alerta renal (ClCr $clcr)"}:** ${renalAlert.length > 150 ? renalAlert.substring(0, 150) + "..." : renalAlert}');
              }
            }
            buf.writeln('');
          }

          if (buf.isNotEmpty) {
            buf.writeln('---');
            buf.writeln(es
                ? '_Apoyo educacional. Confirme con fuente primaria._'
                : '_Apoio educacional. Confirme com fonte primária._');
            return buf.toString();
          }
        }
      }

      // ── 2. RE-TENTATIVA COM QUERY EXPANDIDA (histórico + atual) ────────
      // Cobre casos como "tiene FA" onde FA já foi mencionada antes.
      // Só re-tenta se há histórico real (≥1 msg anterior).
      if (qHistory.isNotEmpty && qHistory.length > 5) {
        // Re-executa o matching usando qExpanded
        if (_has(qExpanded, ['fa ', 'fibrilac atrial', 'fibril atri', 'auricular', 'rr irregular'])) {
          suspected.add('Fibrilação Atrial');
          protocolIds.add('fa_aguda');
        }
        if (_has(qExpanded, ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', 'sca'])) {
          suspected.add(es ? 'Síndrome Coronario Agudo' : 'Síndrome Coronariana Aguda (IAM/Angina Instável)');
          protocolIds.add('iam_congestao');
        }
        if (_has(qExpanded, ['sepse', 'choque sept', 'foco infec', 'bacterem', 'sofa'])) {
          suspected.add('Sepse / Choque Séptico');
          protocolIds.add('sepse');
        }
        if (_has(qExpanded, ['hipertens', 'pressao alta', 'pa elev', 'hta', 'pa alta'])) {
          suspected.add(es ? 'Crisis Hipertensiva' : 'Crise Hipertensiva');
          protocolIds.add('crise_hipertensiva');
        }
        if (_has(qExpanded, ['avc', 'ave', 'acidente vascular', 'isquemia cerebr', 'avc isquem', 'trombose cerebr', 'tpa', 'nihss'])) {
          suspected.add(es ? 'ACV Isquémico' : 'AVC Isquêmico');
          protocolIds.add('avc_isquemico');
        }
        if (_has(qExpanded, ['insuf cardiac', 'ic ', 'dispne', 'edema pulm', 'crepit', 'congest'])) {
          suspected.add(es ? 'Insuficiencia Cardíaca Descompensada' : 'Insuficiência Cardíaca Descompensada');
          protocolIds.add('iam_congestao');
        }
        if (_has(qExpanded, ['hipotens', 'choque', 'pele fria', 'oliguria', 'lactato', 'hipoperfus'])) {
          suspected.add(es ? 'Choque' : 'Choque (cardiogênico / séptico / hipovolêmico)');
          protocolIds.add('choque_cardiogenico');
        }
        if (_has(qExpanded, ['tep', 'embolia pulm', 'tvp', 'trombose venos', 'tromboembol'])) {
          suspected.add(es ? 'Tromboembolismo Pulmonar' : 'Tromboembolismo Pulmonar (TEP)');
          protocolIds.add('tep');
        }
        if (_has(qExpanded, ['bradic', 'bloqueio av', 'bav', 'bav total', 'bav complet'])) {
          suspected.add(es ? 'Bradiarritmia / Bloqueo AV' : 'Bradiarritmia / Bloqueio AV');
          protocolIds.add('bradiarritmia');
        }
        if (_has(qExpanded, ['diabet', 'hiper glyc', 'dka', 'cetoacid', 'hipoglicemi', 'glicose'])) {
          suspected.add(es ? 'Urgencia Diabética (DKA/Hipoglucemia)' : 'Urgência Diabética (DKA/Hipoglicemia)');
          protocolIds.add('dka_hipoglicemia');
        }
        if (_has(qExpanded, ['taquic', 'tvs', 'tv sem pulso', 'fv ', 'fibrilac ventr', 'pcr ', 'reanimac'])) {
          suspected.add(es ? 'Taquiarritmia Ventricular / PCR' : 'Taquiarritmia Ventricular / PCR');
          protocolIds.add('pcr');
        }
      }

      // ── 3. FOLLOW-UP CLÍNICO COM CONTEXTO DO HISTÓRICO ────────────────
      // Quando o usuário faz pergunta curta de seguimento ("e a anticoagulação?",
      // "qual o protocolo?", "quando cardiovertir?") e há histórico ativo.
      if (suspected.isEmpty && _aiHistory.isNotEmpty) {
        final isFollowUp = _has(q, [
          'e a ', 'e o ', 'e os ', 'e as ', 'qual ', 'quando ',
          'como ', 'por que', 'e para', 'e se ', 'pode ',
          'deve ', 'precis', 'protocolo', 'conduta', 'anticoag',
          'cardiovert', 'cardioversao', 'tratar', 'tratamento',
          'manejo', 'fármaco', 'farmaco', 'medicament',
          // espanhol
          'y el ', 'y la ', 'cual ', 'cuando ', 'como ', 'para que',
          'protocolo', 'conducta', 'anticoag', 'cardioversion',
          'tratar', 'tratamiento', 'manejo', 'farmaco', 'medicamento',
        ]);

        if (isFollowUp) {
          // Tenta encontrar o último diagnóstico/condição da conversa
          final lastAssistantMsg = _aiHistory
              .where((m) => m['role'] == 'assistant')
              .map((m) => m['content'] ?? '')
              .lastOrNull ?? '';
          final lastQNorm = _normalize(lastAssistantMsg);

          // Re-tenta extrair protocolo com base no último contexto
          if (_has(lastQNorm, ['fibrilac', 'fa ', 'auricular'])) {
            suspected.add('Fibrilação Atrial');
            protocolIds.add('fa_aguda');
          } else if (_has(lastQNorm, ['sepse', 'choque sept'])) {
            suspected.add('Sepse');
            protocolIds.add('sepse');
          } else if (_has(lastQNorm, ['iam', 'infarto', 'coronar', 'angina'])) {
            suspected.add(es ? 'Síndrome Coronario Agudo' : 'Síndrome Coronariana Aguda');
            protocolIds.add('iam_congestao');
          } else if (_has(lastQNorm, ['avc', 'ave', 'cerebr', 'isquem'])) {
            suspected.add(es ? 'ACV' : 'AVC');
            protocolIds.add('avc_isquemico');
          } else if (_has(lastQNorm, ['hipertens', 'crise hiperten', 'pa elev'])) {
            suspected.add(es ? 'Crisis Hipertensiva' : 'Crise Hipertensiva');
            protocolIds.add('crise_hipertensiva');
          } else if (_has(lastQNorm, ['tep', 'embolia pulm', 'tromboembol'])) {
            suspected.add(es ? 'TEP' : 'TEP');
            protocolIds.add('tep');
          } else if (_has(lastQNorm, ['insuf cardiac', 'ic ', 'edema pulm', 'congest'])) {
            suspected.add(es ? 'Insuficiencia Cardíaca' : 'Insuficiência Cardíaca');
            protocolIds.add('iam_congestao');
          }
        }
      }

      // ── 4. FALLBACK FINAL — só chega aqui se realmente não há contexto ──
      if (suspected.isEmpty) {
        // Se há histórico, oferece opções relacionadas ao contexto anterior
        if (_aiHistory.isNotEmpty) {
          final lastUser = _aiHistory
              .where((m) => m['role'] == 'user')
              .map((m) => m['content'] ?? '')
              .lastOrNull ?? '';
          final contextHint = lastUser.isNotEmpty
              ? (es
                  ? '\n_Contexto anterior: "$lastUser"_\n\n'
                  : '\n_Contexto anterior: "$lastUser"_\n\n')
              : '';
          return es
              ? '${contextHint}Entiendo que tienes una pregunta de seguimiento. ¿Podrías especificar un poco más?\n\nPor ejemplo:\n• "¿Cuál es la dosis de [fármaco]?"\n• "¿Cuándo cardiovertir en FA?"\n• "¿Qué anticoagulante usar?"\n• "¿Cuál es el protocolo de manejo?"\n\n⚕ Apoyo educacional.'
              : '${contextHint}Entendo que é uma pergunta de seguimento. Pode especificar um pouco mais?\n\nPor exemplo:\n• "Qual a dose de [fármaco]?"\n• "Quando cardioverter na FA?"\n• "Qual anticoagulante usar?"\n• "Qual o protocolo de manejo?"\n\n⚕ Apoio educacional.';
        }
        // Sem nenhum histórico: pede contexto clínico
        final ask = es
            ? 'Puedo ayudarte mejor si me cuentas más sobre el caso clínico.\n\n**Sugerencias:**\n• Síntomas principales y tiempo de evolución\n• Signos vitales (PA, FC, SpO₂, temperatura)\n• Datos del paciente (edad, peso, antecedentes)\n• Fármaco o condición específica que quieres consultar\n\nEjemplos:\n• "Paciente con FA + hipotensión, ¿cuál es la conducta?"\n• "¿Cuál es la dosis de amiodarona en FA?"\n• "Sepsis: protocolo de antibióticos"'
            : 'Posso ajudar melhor com mais detalhes sobre o caso clínico.\n\n**Sugestões:**\n• Sintomas principais e tempo de evolução\n• Sinais vitais (PA, FC, SpO₂, temperatura)\n• Dados do paciente (idade, peso, antecedentes)\n• Fármaco ou condição específica que deseja consultar\n\nExemplos:\n• "Paciente com FA + hipotensão, qual a conduta?"\n• "Qual a dose de amiodarona na FA?"\n• "Sepse: protocolo de antibióticos"';
        return '$ask\n\n⚕ Apoio educacional.';
      }
    }

    // ── Montar resposta ──────────────────────────────────────────────────
    final clcrStr = clcr ?? '—';

    // Hipóteses — só as 3 mais relevantes
    if (suspected.length == 1) {
      buf.writeln('## ${suspected[0]}');
    } else {
      buf.writeln('## Hipóteses:');
      for (int i = 0; i < suspected.length && i < 3; i++) {
        buf.writeln('  ${i + 1}. ${suspected[i]}');
      }
    }
    buf.writeln('');

    // Red Flags — máx 3, apenas os mais críticos
    if (redFlags.isNotEmpty) {
      buf.writeln('## Alertas:');
      for (final f in redFlags.take(3)) {
        buf.writeln('  • $f');
      }
      buf.writeln('');
    }

    // Protocolo + conduta (o mais valioso)
    ProtocolModel? matchedProtocol;
    for (final pid in protocolIds) {
      try {
        matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == pid);
        break;
      } catch (_) {}
    }

    if (matchedProtocol != null) {
      buf.writeln('## ${tDB(matchedProtocol.title)}:');
      final actions = matchedProtocol.getActions(_lang);
      for (int i = 0; i < actions.length && i < 5; i++) {
        buf.writeln('  ${actions[i]}');
      }
      if (actions.length > 5) {
        buf.writeln(_lang == 'es'
            ? '  → Ver protocolo completo en la pestaña Protocolos'
            : '  → Ver protocolo completo na aba Protocolos');
      }
      buf.writeln('');

      // Fármacos — só se tem paciente com peso (dose personalizada tem valor real)
      final suggestedDrugs = matchedProtocol.drugs.take(3)
          .map((id) {
            try { return drugsDatabase.firstWhere((d) => d.id == id); }
            catch (_) { return null; }
          })
          .whereType<DrugModel>().toList();

      if (suggestedDrugs.isNotEmpty && _patient.weight.isNotEmpty) {
        buf.writeln('## ${_lang == 'es' ? 'Dosis para este paciente:' : 'Dose para este paciente:'}');
        for (final drug in suggestedDrugs) {
          final dose = calculateDose(drug);
          final alerts = dose.alerts.take(1).join(' | ');
          buf.writeln('  • ${drug.name}: ${dose.main}${alerts.isNotEmpty ? '  ⚠ $alerts' : ''}');
        }
        buf.writeln('');
      } else if (suggestedDrugs.isNotEmpty) {
        // Sem peso: lista fármacos sem calcular dose
        final names = suggestedDrugs.map((d) => d.name).join(', ');
        buf.writeln('Fármacos: $names');
        buf.writeln('');
      }
    } else if (examSuggestions.isNotEmpty) {
      // Sem protocolo direto: mostra só os exames mais relevantes (máx 4)
      final uniq = examSuggestions.toSet().take(4).toList();
      buf.writeln('## ${_lang == 'es' ? 'Exámenes clave:' : 'Exames-chave:'}');
      for (final e in uniq) buf.writeln('  • $e');
      buf.writeln('');
    }

    // Alerta renal — só se ClCr relevantemente baixo
    final clcrVal = double.tryParse(clcrStr.replaceAll(',', '.'));
    if (clcrVal != null && clcrVal > 0 && clcrVal < 45) {
      final level = clcrVal < 15 ? 'ALERTA' : 'Aten.';
      buf.writeln('$level ${_lang == 'es' ? 'ClCr $clcrStr — ajustar dosis renales' : 'ClCr $clcrStr — ajustar doses renais'}');
      buf.writeln('');
    }

    // Alerta de idade — só uma linha compacta
    final ageVal = int.tryParse(_patient.age);
    if (ageVal != null && ageVal >= 75) {
      buf.writeln(_lang == 'es' ? 'Idoso: reducir dosis opioides/BZD, vigilar delirium.' : 'Idoso: reduzir dose opioides/BZD, vigilar delirium.');
      buf.writeln('');
    }

    buf.writeln('Apoio educacional. Sempre confirme com fonte primária.');
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
