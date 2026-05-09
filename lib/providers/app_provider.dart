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
  String _lang = 'pt';
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

  // ── Getters públicos ──────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get firebaseReady => _firebaseReady;
  bool get loggedIn => _currentUser != null && _currentUser!.isApproved;
  bool get isPending => _currentUser != null && _currentUser!.isPending;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
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

  List<DrugModel> get drugsDB => drugsDatabase;
  List<ProtocolModel> get protocolsDB => protocolsDatabase;
  List<ClinicalCaseModel> get casesDB => casesDatabase;

  DrugModel? get activeDrug => _activeDrugId.isEmpty
      ? null
      : drugsDatabase.firstWhere((d) => d.id == _activeDrugId, orElse: () => drugsDatabase[0]);

  List<DrugModel> get selectedDrugs =>
      _selectedDrugIds.map((id) => drugsDatabase.firstWhere((d) => d.id == id, orElse: () => drugsDatabase[0])).toList();

  // ── Login com usuário do Firebase ─────────────────────────────────────────
  Future<void> setUser(UserModel user) async {
    _currentUser = user;
    _lang = user.lang;
    _darkMode = user.darkMode;
    _firebaseReady = true;
    notifyListeners();
    // Carregar dados do Firestore
    await _loadFromFirestore(user.uid);
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
    notifyListeners();
  }

  void setFirebaseReady() {
    _firebaseReady = true;
    notifyListeners();
  }

  // ── Carregar dados do Firestore ───────────────────────────────────────────
  Future<void> _loadFromFirestore(String uid) async {
    try {
      final favDrugs = await FirestoreService.loadFavDrugs(uid);
      final favProtocols = await FirestoreService.loadFavProtocols(uid);
      final cases = await FirestoreService.loadCases(uid);
      _favDrugs = favDrugs;
      _favProtocols = favProtocols;
      _customCases = cases;
      notifyListeners();
      // Carrega histórias clínicas em paralelo (sem bloquear UI)
      loadHistories().catchError((_) {});
    } catch (_) {
      // Fallback para SharedPreferences se offline
      await _loadFromLocal();
    }
  }

  // ── Fallback local ────────────────────────────────────────────────────────
  Future<void> loadPrefs() async {
    await _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      _lang = p.getString('lang') ?? 'pt';
      _darkMode = p.getBool('darkMode') ?? false;
      _favDrugs = (p.getStringList('favDrugs') ?? []).toSet();
      _favProtocols = (p.getStringList('favProtocols') ?? []).toSet();
      final casesJson = p.getString('customCases');
      if (casesJson != null) {
        try {
          final list = jsonDecode(casesJson) as List;
          _customCases = list.map((e) => ClinicalCaseModel.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', _lang);
      await p.setBool('darkMode', _darkMode);
      await p.setStringList('favDrugs', _favDrugs.toList());
      await p.setStringList('favProtocols', _favProtocols.toList());
      await p.setString('customCases', jsonEncode(_customCases.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  // ── i18n helpers ──────────────────────────────────────────────────────────
  String tDB(Map<String, String>? field) {
    if (field == null) return '';
    return field[_lang] ?? field['pt'] ?? field['es'] ?? '';
  }

  String t(String key) {
    return _translations[_lang]?[key] ?? _translations['pt']?[key] ?? key;
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
    } catch (_) {}
  }

  Future<void> saveHistory(ClinicalHistoryModel h) async {
    if (_currentUser == null) return;
    await FirestoreService.saveHistory(_currentUser!.uid, h);
    final idx = _myHistories.indexWhere((x) => x.id == h.id);
    if (idx >= 0) {
      _myHistories[idx] = h;
    } else {
      _myHistories.insert(0, h);
    }
    notifyListeners();
  }

  Future<void> deleteHistory(String id, {bool wasPublic = false}) async {
    if (_currentUser == null) return;
    await FirestoreService.deleteHistory(_currentUser!.uid, id, wasPublic: wasPublic);
    _myHistories.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  Future<void> toggleHistoryPublic(ClinicalHistoryModel h) async {
    final updated = h.copyWith(isPublic: !h.isPublic);
    await saveHistory(updated);
  }

  Future<void> loadPublicHistories() async {
    try {
      _publicHistories = await FirestoreService.loadPublicHistories();
      notifyListeners();
    } catch (_) {}
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void logout() {
    clearUser();
  }

  // ── IA Clínica ────────────────────────────────────────────────────────────
  String buildAIAnswer(String input) {
    final q = _normalize(input);
    final buf = StringBuffer();
    final suspected = <String>[];
    final protocolIds = <String>[];
    final examSuggestions = <String>[];
    final redFlags = <String>[];

    // ── Síndromes cardiovasculares ─────────────────────────────────────────
    if (_has(q, ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', 'sca'])) {
      suspected.add('Síndrome Coronariana Aguda (IAM/Angina Instável)');
      protocolIds.add('iam_congestao');
      examSuggestions.addAll(['ECG seriado (0–6–12h)', 'Troponina (0–3h)', 'RX tórax', 'Glicemia']);
      redFlags.addAll(['Supradesnivelamento ST → cateterismo urgente', 'Hipotensão → choque cardiogênico']);
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
    if (_has(q, ['cefal', 'dor cabeca', 'trovoada', 'pior cefaleia', 'meningismo', 'rigidez nuca'])) {
      suspected.add('Cefaleia Grave (Hemorragia Subaracnóidea / Meningite)');
      protocolIds.add('avc_hemorragico');
      examSuggestions.addAll(['TC crânio (excluir HSA)', 'Punção lombar se TC negativa', 'Hemoculturas se meningismo', 'PCR/hemograma']);
      redFlags.add('"Pior cefaleia da vida" ou início súbito → excluir HSA urgente');
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

    if (suspected.isEmpty) {
      suspected.add('Síndrome clínica inespecífica — descreva mais detalhes do caso');
      examSuggestions.addAll(['Sinais vitais completos (PA, FC, FR, Temp, SpO2)', 'Glicemia capilar', 'ECG 12 derivações', 'Hemograma completo', 'Eletrólitos (Na+, K+, Ca2+)', 'Função renal (Cr, Ureia)', 'Gasometria arterial se grave']);
    }

    // ── Montar resposta ──────────────────────────────────────────────────
    final isEs = _lang == 'es';

    // Cabeçalho
    buf.writeln('🧠 IA Clínica — Raciocínio Diagnóstico');
    buf.writeln('');

    // Perfil do paciente
    final age = _patient.age.isNotEmpty ? '${_patient.age} anos' : '—';
    final wt  = _patient.weight.isNotEmpty ? '${_patient.weight} kg' : '—';
    final clcrStr = clcr ?? '—';
    final bmiStr  = bmi  ?? '—';
    buf.writeln('👤 Paciente: $age | ${_patient.sex} | $wt');
    buf.writeln('   ClCr: $clcrStr mL/min | IMC: $bmiStr kg/m²');
    buf.writeln('');

    // Hipóteses diagnósticas
    buf.writeln('📋 Hipóteses diagnósticas:');
    for (int i = 0; i < suspected.length && i < 5; i++) {
      buf.writeln('  ${i + 1}. ${suspected[i]}');
    }
    buf.writeln('');

    // Red Flags
    if (redFlags.isNotEmpty) {
      buf.writeln('🚨 Alertas imediatos:');
      for (final f in redFlags.take(5)) {
        buf.writeln('  ⛔ $f');
      }
      buf.writeln('');
    }

    // Exames
    if (examSuggestions.isNotEmpty) {
      final uniqExams = examSuggestions.toSet().toList();
      buf.writeln('🔬 Exames prioritários:');
      for (final e in uniqExams.take(8)) {
        buf.writeln('  • $e');
      }
      buf.writeln('');
    }

    // Protocolo aplicável
    ProtocolModel? matchedProtocol;
    for (final pid in protocolIds) {
      try {
        matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == pid);
        break;
      } catch (_) {}
    }

    if (matchedProtocol != null) {
      buf.writeln('📌 Protocolo: ${tDB(matchedProtocol.title)}');
      buf.writeln('');
      buf.writeln('🩺 Conduta imediata:');
      final actions = matchedProtocol.getActions(_lang);
      for (int i = 0; i < actions.length && i < 6; i++) {
        buf.writeln('  ${actions[i]}');
      }
      if (actions.length > 6) {
        buf.writeln('  → Ver protocolo completo na aba Protocolos');
      }
      buf.writeln('');
      buf.writeln('🚫 Não fazer: ${tDB(matchedProtocol.avoid)}');
      buf.writeln('');

      // Fármacos com dose calculada para o paciente atual
      final suggestedDrugs = matchedProtocol.drugs.take(4)
          .map((id) {
            try { return drugsDatabase.firstWhere((d) => d.id == id); }
            catch (_) { return null; }
          })
          .whereType<DrugModel>().toList();

      if (suggestedDrugs.isNotEmpty) {
        buf.writeln('💊 Fármacos (dose para ESTE paciente):');
        for (final drug in suggestedDrugs) {
          final dose = calculateDose(drug);
          buf.writeln('  • ${drug.name}');
          buf.writeln('    Dose: ${dose.main}');
          if (dose.detail.isNotEmpty) {
            buf.writeln('    ${dose.detail}');
          }
          if (dose.alerts.isNotEmpty) {
            for (final a in dose.alerts) {
              buf.writeln('    ⚠ $a');
            }
          }
        }
        buf.writeln('');
      }
    }

    // Alertas renais personalizados
    final clcrVal = double.tryParse(clcrStr.replaceAll(',', '.'));
    if (clcrVal != null && clcrVal > 0 && clcrVal < 60) {
      buf.writeln('🫘 Alerta renal (ClCr $clcrStr mL/min):');
      if (clcrVal < 15) {
        buf.writeln('  ⛔ IRC grave/terminal — ajuste obrigatório em TODOS os fármacos');
        buf.writeln('  ⛔ Evitar: AINE, metformina, aminoglicosídeos, nitrofurantoína');
        buf.writeln('  ⛔ Dosar nível sérico: vancomicina, digoxina, lítio');
      } else if (clcrVal < 30) {
        buf.writeln('  ⚠ IRC moderada-grave — revisar doses e intervalos');
        buf.writeln('  ⚠ Evitar: AINE, metformina, doses plenas de HBPM');
      } else {
        buf.writeln('  ⚠ IRC leve-moderada — atenção a nefrotóxicos e doses');
        buf.writeln('  ⚠ Monitorar: creatinina, eletrólitos, diurese');
      }
      buf.writeln('');
    }

    // Alerta de idade
    final ageVal = int.tryParse(_patient.age);
    if (ageVal != null && ageVal >= 75) {
      buf.writeln('👴 Alerta idoso (${_patient.age} anos):');
      buf.writeln('  • Polifarmácia — revisar lista completa de medicamentos');
      buf.writeln('  • Doses reduzidas: opioides, benzodiazepínicos, anticolinérgicos');
      buf.writeln('  • Risco aumentado: delirium, quedas, hipotensão ortostática');
      buf.writeln('  • Usar critérios de Beers para medicamentos inapropriados');
      buf.writeln('');
    }

    // Rodapé
    buf.writeln('─────────────────────────────────────');
    buf.writeln('⚕ Apoio educacional. NÃO substitui avaliação médica presencial.');
    buf.writeln('Revisar: alergias, gestação, ECG, função renal/hepática, interações e protocolo institucional.');
    return buf.toString();
  }

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
      'age': 'Idade', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'drug': 'Fármaco', 'dose': 'Dose calculada', 'route': 'Via',
      'className': 'Classe', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'recognize': 'Reconhecer',
      'actions': 'Conduta imediata', 'avoid': 'Não fazer',
      'cockpit': 'Início', 'protocols': 'Protocolos', 'drugs': 'Fármaco',
      'cases': 'Casos', 'tools': 'Tools', 'ai': 'IA Clínica',
      'send': 'Enviar', 'clear': 'Limpar', 'copied': 'Copiado!',
      'logout': 'Sair', 'login': 'Entrar', 'save': 'Salvar',
      'back': 'Voltar', 'delete': 'Excluir', 'edit': 'Editar',
      'new': 'Novo', 'cancel': 'Cancelar', 'search': 'Pesquisar',
      'admin': 'Admin',
    },
    'es': {
      'age': 'Edad', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'drug': 'Fármaco', 'dose': 'Dosis calculada', 'route': 'Vía',
      'className': 'Clase', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'recognize': 'Reconocer',
      'actions': 'Conducta inmediata', 'avoid': 'No hacer',
      'cockpit': 'Inicio', 'protocols': 'Protocolos', 'drugs': 'Fármaco',
      'cases': 'Casos', 'tools': 'Herramientas', 'ai': 'IA Clínica',
      'send': 'Enviar', 'clear': 'Limpiar', 'copied': '¡Copiado!',
      'logout': 'Salir', 'login': 'Acceder', 'save': 'Guardar',
      'back': 'Volver', 'delete': 'Eliminar', 'edit': 'Editar',
      'new': 'Nuevo', 'cancel': 'Cancelar', 'search': 'Buscar',
      'admin': 'Admin',
    },
  };
}
