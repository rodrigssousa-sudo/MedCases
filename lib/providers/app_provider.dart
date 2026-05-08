import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drug_model.dart';
import '../models/protocol_model.dart';
import '../models/clinical_case_model.dart';
import '../data/drugs_database.dart';
import '../data/protocols_database.dart';
import '../data/cases_database.dart';

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

  PatientData({
    this.patientId = 'Leito / Box',
    this.age = '68',
    this.sex = 'Masculino',
    this.weight = '78',
    this.height = '171',
    this.creatinine = '1.0',
  });
}

class HemoData {
  String sbp, dbp, na, cl, hco3, glucose;
  HemoData({
    this.sbp = '120',
    this.dbp = '80',
    this.na = '140',
    this.cl = '104',
    this.hco3 = '24',
    this.glucose = '100',
  });
}

class AppProvider extends ChangeNotifier {
  String _lang = 'pt';
  bool _loggedIn = false;
  String _userName = '';
  bool _darkMode = false;

  PatientData _patient = PatientData();
  HemoData _hemo = HemoData();

  List<String> _selectedDrugIds = ['furosemida'];
  String _activeDrugId = 'furosemida';

  List<ClinicalCaseModel> _customCases = [];
  Set<String> _favDrugs = {};
  Set<String> _favProtocols = {};

  String get lang => _lang;
  bool get loggedIn => _loggedIn;
  String get userName => _userName;
  bool get darkMode => _darkMode;
  PatientData get patient => _patient;
  HemoData get hemo => _hemo;
  String get activeDrugId => _activeDrugId;
  List<String> get selectedDrugIds => _selectedDrugIds;
  Set<String> get favDrugs => _favDrugs;
  Set<String> get favProtocols => _favProtocols;
  List<ClinicalCaseModel> get customCases => _customCases;

  List<DrugModel> get drugsDB => drugsDatabase;
  List<ProtocolModel> get protocolsDB => protocolsDatabase;
  List<ClinicalCaseModel> get casesDB => casesDatabase;

  DrugModel get activeDrug =>
      drugsDatabase.firstWhere((d) => d.id == _activeDrugId, orElse: () => drugsDatabase[0]);

  List<DrugModel> get selectedDrugs =>
      _selectedDrugIds.map((id) => drugsDatabase.firstWhere((d) => d.id == id, orElse: () => drugsDatabase[0])).toList();

  String tDB(Map<String, String>? field) {
    if (field == null) return '';
    return field[_lang] ?? field['pt'] ?? field['es'] ?? '';
  }

  String t(String key) {
    return _translations[_lang]?[key] ?? _translations['pt']?[key] ?? key;
  }

  // ── Clinical calculations ──────────────────────────────────────────────────

  double? _parseNum(String val) {
    final v = double.tryParse(val.replaceAll(',', '.'));
    return (v != null && v.isFinite) ? v : null;
  }

  String _fmt(double v) {
    if (!v.isFinite) return '—';
    if (v.abs() >= 100) return v.round().toString();
    return (v * 10).round() / 10 == (v * 10).round() / 10
        ? ((v * 10).round() / 10).toString().replaceAll('.', ',')
        : v.toStringAsFixed(1).replaceAll('.', ',');
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
      alerts.add('${_lang == 'es' ? 'Ajuste renal: ClCr ' : 'Ajuste renal: ClCr '}${clcr ?? '—'} mL/min. $renalAlert');
    }

    final elderlyAlert = drug.getField(drug.elderlyAlert, _lang);
    if (a != null && a >= 65 && elderlyAlert.isNotEmpty) {
      alerts.add('${_lang == 'es' ? 'Paciente anciano: ' : 'Paciente idoso: '}$elderlyAlert');
    }

    if (drug.doseType == 'weight' && w != null && drug.mgKg != null) {
      return DoseInfo(
        main: '${_fmt(w * drug.mgKg!)} mg/dose',
        detail: '${drug.mgKg} mg/kg. ${drug.getField(drug.frequency, _lang).isNotEmpty ? drug.getField(drug.frequency, _lang) : (_lang == 'es' ? 'Frecuencia según protocolo.' : 'Frequência conforme protocolo.')}',
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
    final doseNote = '';
    return DoseInfo(
      main: fixedDose.isNotEmpty ? fixedDose : (_lang == 'es' ? 'Dosis según protocolo local' : 'Dose conforme protocolo local'),
      detail: doseNote.isNotEmpty ? doseNote : (_lang == 'es' ? 'Individualizar por indicación, función renal/hepática, alergias y presentación disponible.' : 'Individualizar por indicação, função renal/hepática, alergias e apresentação disponível.'),
      alerts: alerts,
    );
  }

  List<String> get interactionRisks {
    final ids = _selectedDrugIds.toSet();
    final risks = <String>[];

    bool has(String a, String b) => ids.contains(a) && ids.contains(b);
    bool hasAny(List<String> a, List<String> b) => a.any((x) => ids.contains(x)) && b.any((y) => ids.contains(y));

    if (hasAny(['aas', 'clopidogrel'], ['rivaroxabana', 'apixabana', 'enoxaparina', 'heparina_nf'])) {
      risks.add(_lang == 'es'
          ? 'Antiagregante + anticoagulante: aumenta bastante el riesgo de sangrado.'
          : 'Antiagregante + anticoagulante: aumenta bastante o risco de sangramento.');
    }
    if (has('aas', 'cetorolaco')) {
      risks.add(_lang == 'es'
          ? 'AAS + ketorolaco/AINE: mayor riesgo de sangrado gastrointestinal y lesión renal.'
          : 'AAS + cetorolaco/AINE: maior risco de sangramento gastrointestinal e lesão renal.');
    }
    if (has('furosemida', 'digoxina')) {
      risks.add(_lang == 'es'
          ? 'Furosemida + digoxina: hipopotasemia aumenta riesgo de intoxicación digitálica.'
          : 'Furosemida + digoxina: hipocalemia aumenta risco de intoxicação digitálica.');
    }
    if (has('enalapril', 'espironolactona')) {
      risks.add(_lang == 'es'
          ? 'IECA + espironolactona: riesgo de hiperpotasemia en ERC y ancianos.'
          : 'IECA + espironolactona: risco de hipercalemia em DRC e idosos.');
    }
    if (has('morfina', 'pregabalina')) {
      risks.add(_lang == 'es'
          ? 'Opioide + pregabalina: mayor riesgo de sedación y depresión respiratoria.'
          : 'Opioide + pregabalina: maior risco de sedação e depressão respiratória.');
    }

    return risks;
  }

  // ── State mutations ────────────────────────────────────────────────────────

  void login(String name) {
    _loggedIn = true;
    _userName = name;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    _userName = '';
    notifyListeners();
  }

  void setLang(String l) {
    _lang = l;
    _savePrefs();
    notifyListeners();
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    _savePrefs();
    notifyListeners();
  }

  void updatePatient(String key, String value) {
    switch (key) {
      case 'patientId': _patient.patientId = value; break;
      case 'age': _patient.age = value; break;
      case 'sex': _patient.sex = value; break;
      case 'weight': _patient.weight = value; break;
      case 'height': _patient.height = value; break;
      case 'creatinine': _patient.creatinine = value; break;
    }
    notifyListeners();
  }

  void resetPatient() {
    _patient = PatientData(patientId: '', age: '', sex: 'Masculino', weight: '', height: '', creatinine: '');
    notifyListeners();
  }

  void updateHemo(String key, String value) {
    switch (key) {
      case 'sbp': _hemo.sbp = value; break;
      case 'dbp': _hemo.dbp = value; break;
      case 'na': _hemo.na = value; break;
      case 'cl': _hemo.cl = value; break;
      case 'hco3': _hemo.hco3 = value; break;
      case 'glucose': _hemo.glucose = value; break;
    }
    notifyListeners();
  }

  void setActiveDrug(String id) {
    _activeDrugId = id;
    if (!_selectedDrugIds.contains(id)) {
      _selectedDrugIds.add(id);
    }
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
    if (_selectedDrugIds.isEmpty) _selectedDrugIds.add(drugsDatabase[0].id);
    if (_activeDrugId == id) _activeDrugId = _selectedDrugIds.first;
    notifyListeners();
  }

  void toggleFavDrug(String id) {
    if (_favDrugs.contains(id)) _favDrugs.remove(id);
    else _favDrugs.add(id);
    _savePrefs();
    notifyListeners();
  }

  void toggleFavProtocol(String id) {
    if (_favProtocols.contains(id)) _favProtocols.remove(id);
    else _favProtocols.add(id);
    _savePrefs();
    notifyListeners();
  }

  void saveCase(ClinicalCaseModel c) {
    final idx = _customCases.indexWhere((x) => x.id == c.id);
    if (idx >= 0) _customCases[idx] = c;
    else _customCases.insert(0, c);
    _savePrefs();
    notifyListeners();
  }

  void deleteCase(String id) {
    _customCases.removeWhere((c) => c.id == id);
    _savePrefs();
    notifyListeners();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> loadPrefs() async {
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

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', _lang);
    await p.setBool('darkMode', _darkMode);
    await p.setStringList('favDrugs', _favDrugs.toList());
    await p.setStringList('favProtocols', _favProtocols.toList());
    await p.setString('customCases', jsonEncode(_customCases.map((c) => c.toJson()).toList()));
  }

  // ── AI ─────────────────────────────────────────────────────────────────────

  String buildAIAnswer(String input) {
    final q = _normalize(input);
    final buf = StringBuffer();

    final suspected = <String>[];
    if (_has(q, ['dor torac', 'peito', 'iam', 'infarto', 'angina'])) suspected.add('Síndrome coronariana aguda / IAM');
    if (_has(q, ['dispne', 'falta de ar', 'crepit', 'congest', 'edema pulm', 'ortopneia'])) suspected.add('IC descompensada / congestão pulmonar');
    if (_has(q, ['hipotens', 'choque', 'pele fria', 'oliguria', 'lactato'])) suspected.add('Choque: cardiogênico, séptico, obstrutivo ou hipovolêmico');
    if (_has(q, ['urtic', 'anafil', 'broncoespas', 'angioedema', 'alerg'])) suspected.add('Anafilaxia');
    if (_has(q, ['taquic', 'palpit', 'qrs', 'tpsv', 'arritm'])) suspected.add('Taquiarritmia / TPSV');
    if (_has(q, ['tvp', 'tep', 'embolia', 'panturrilha'])) suspected.add('TVP / TEP');
    if (_has(q, ['potass', 'hipercal', 'k+', 'bradica'])) suspected.add('Hipercalemia');
    if (_has(q, ['glicos', 'cetoacid', 'diabetes', 'cetona'])) suspected.add('Cetoacidose diabética');
    if (_has(q, ['febre', 'sepse', 'infec', 'pneumon'])) suspected.add('Infecção grave / sepse');
    if (suspected.isEmpty) suspected.add('Síndrome clínica inespecífica — preciso de mais dados');

    buf.writeln('🧠 IA clínica integrada — raciocínio inicial\n');
    buf.writeln('Paciente: ${_patient.age.isNotEmpty ? _patient.age : '—'} anos | ${_patient.sex} | ${_patient.weight.isNotEmpty ? _patient.weight : '—'} kg | ClCr ${clcr ?? '—'} mL/min | IMC ${bmi ?? '—'}\n');
    buf.writeln('Hipóteses possíveis:');
    for (final s in suspected.take(4)) buf.writeln('• $s');
    buf.writeln('\nRed flags:');
    buf.writeln('• Hipotensão, rebaixamento, SatO2 baixa, dor torácica persistente, síncope, alteração de ECG, lactato alto ou oligúria.');
    buf.writeln('• Se instável: ABCDE, monitor, acesso venoso, ECG e suporte hemodinâmico.\n');
    buf.writeln('Exames úteis:');
    buf.writeln('• Sinais vitais seriados, ECG, glicemia capilar, eletrólitos, função renal, hemograma, gasometria/lactato se grave.');
    buf.writeln('• Troponina, BNP, Rx, eco ou angioTC conforme hipótese.\n');

    ProtocolModel? matchedProtocol;
    final suspectedStr = suspected.join(' ').toLowerCase();
    if (suspectedStr.contains('iam')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'iam_congestao', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('choque') && suspectedStr.contains('septic')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'choque_septico', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('choque')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'choque_cardiogenico', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('anafilaxia')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'anafilaxia', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('tpsv')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'tpsv', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('tep')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'tep_instavel', orElse: () => protocolsDatabase[0]);
    else if (suspectedStr.contains('hipercalemia')) matchedProtocol = protocolsDatabase.firstWhere((p) => p.id == 'hipercalemia', orElse: () => protocolsDatabase[0]);

    if (matchedProtocol != null) {
      buf.writeln('Protocolo: ${tDB(matchedProtocol.title)}');
      buf.writeln('Reconhecer: ${tDB(matchedProtocol.recognize)}');
      buf.writeln('\nConduta imediata:');
      for (final a in matchedProtocol.getActions(_lang)) buf.writeln('• $a');
      buf.writeln('\nNão fazer: ${tDB(matchedProtocol.avoid)}\n');

      final suggestedDrugs = matchedProtocol.drugs.take(4).map((id) {
        try { return drugsDatabase.firstWhere((d) => d.id == id); } catch (_) { return null; }
      }).whereType<DrugModel>().toList();

      if (suggestedDrugs.isNotEmpty) {
        buf.writeln('Doses pela base do app:');
        for (final drug in suggestedDrugs) {
          final dose = calculateDose(drug);
          buf.writeln('• ${drug.name}: ${dose.main}');
          if (dose.alerts.isNotEmpty) buf.writeln('  ⚠ ${dose.alerts.join(' | ')}');
        }
        buf.writeln();
      }
    }

    buf.writeln('Segurança: apoio educacional. Revisar alergias, gestação, ECG, K+/Mg2+, função renal/hepática, interações e protocolo local antes de prescrever.');
    return buf.toString();
  }

  String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[àáâãäå]'), 'a').replaceAll(RegExp(r'[èéêë]'), 'e').replaceAll(RegExp(r'[ìíîï]'), 'i').replaceAll(RegExp(r'[òóôõö]'), 'o').replaceAll(RegExp(r'[ùúûü]'), 'u').replaceAll(RegExp(r'[ç]'), 'c').replaceAll(RegExp(r'[ñ]'), 'n');

  bool _has(String q, List<String> words) => words.any((w) => q.contains(w));

  // ── i18n ───────────────────────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _translations = {
    'pt': {
      'age': 'Idade', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'drug': 'Fármaco', 'dose': 'Dose calculada', 'route': 'Via',
      'className': 'Classe', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'recognize': 'Reconhecer',
      'actions': 'Conduta imediata', 'avoid': 'Não fazer',
      'cockpit': 'Início', 'protocols': 'Protocolos', 'drugs': 'Rx',
      'cases': 'Casos', 'tools': 'Tools', 'ai': 'IA Clínica',
      'send': 'Enviar', 'clear': 'Limpar', 'copied': 'Copiado!',
      'logout': 'Sair', 'login': 'Entrar', 'save': 'Salvar',
      'back': 'Voltar', 'delete': 'Excluir', 'edit': 'Editar',
      'new': 'Novo', 'cancel': 'Cancelar', 'search': 'Pesquisar',
    },
    'es': {
      'age': 'Edad', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'drug': 'Fármaco', 'dose': 'Dosis calculada', 'route': 'Vía',
      'className': 'Clase', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'recognize': 'Reconocer',
      'actions': 'Conducta inmediata', 'avoid': 'No hacer',
      'cockpit': 'Inicio', 'protocols': 'Protocolos', 'drugs': 'Rx',
      'cases': 'Casos', 'tools': 'Herramientas', 'ai': 'IA Clínica',
      'send': 'Enviar', 'clear': 'Limpiar', 'copied': '¡Copiado!',
      'logout': 'Salir', 'login': 'Acceder', 'save': 'Guardar',
      'back': 'Volver', 'delete': 'Eliminar', 'edit': 'Editar',
      'new': 'Nuevo', 'cancel': 'Cancelar', 'search': 'Buscar',
    },
  };
}
