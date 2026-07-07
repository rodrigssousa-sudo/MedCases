import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/drug_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CloudClinicalDataService — BUILD 324.1
//
// Formulário de 628 fármacos servido a partir de JSON remoto no GitHub,
// com cache em arquivo local via path_provider para resiliência offline.
//
// Estratégia de carga (em ordem de prioridade):
//   1. Remote fetch  → raw.githubusercontent.com (5 s timeout)
//                       → grava/atualiza cache local em background
//   2. File cache    → path_provider, persiste entre sessões
//                       → usado quando sem rede após o 1º boot
//
// Sem bundle no app: o JSON NÃO é registrado como asset no pubspec.yaml,
// portanto não é compilado no binário — binário permanece leve.
//
// Consumidores usam o mesmo tipo DrugModel — zero mudanças na UI.
// ─────────────────────────────────────────────────────────────────────────────

class CloudClinicalDataService {
  CloudClinicalDataService._();
  static final CloudClinicalDataService instance = CloudClinicalDataService._();

  // ── Fonte canônica — assets/ do repositório MedCases (raw GitHub) ──────────
  // O arquivo assets/drugs_database.json é versionado no repo MedCases mas NÃO
  // é registrado como asset Flutter (não entra no binário do app).
  // Acessado exclusivamente via HTTP ao inicializar — zero impacto no bundle.
  static const _remoteUrl =
      'https://raw.githubusercontent.com/rodrigssousa-sudo/MedCases/main/assets/drugs_database.json';

  // Cache local
  static const _cacheFileName = 'drugs_database_cache_v1.json';
  static const _fetchTimeout  = Duration(seconds: 5);

  List<DrugModel> _drugs   = const [];
  bool            _loaded  = false;
  bool            _loading = false;

  /// Snapshot imutável do formulário carregado.
  List<DrugModel> get drugs    => _drugs;
  bool            get isLoaded => _loaded;

  /// Idempotente — seguro chamar múltiplas vezes.
  Future<void> init() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      await _load();
    } catch (e, st) {
      debugPrint('[CloudClinical] init error: $e\n$st');
    } finally {
      _loading = false;
    }
  }

  // ── Lógica interna ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    // 1. Fetch remoto — fonte verdade; atualiza cache em background
    try {
      final data = await _fetchRemote();
      if (data != null && data.isNotEmpty) {
        _drugs  = List.unmodifiable(data);
        _loaded = true;
        unawaited(_writeCache(data));
        debugPrint('[CloudClinical] ✓ ${_drugs.length} fármacos carregados do remoto.');
        return;
      }
    } catch (_) {}

    // 2. Cache local (path_provider) — resiliência offline após 1º boot
    try {
      final data = await _readCache();
      if (data != null && data.isNotEmpty) {
        _drugs  = List.unmodifiable(data);
        _loaded = true;
        debugPrint('[CloudClinical] ✓ ${_drugs.length} fármacos carregados do cache.');
        return;
      }
    } catch (_) {}

    // Sem rede E sem cache → formulário vazio; RAG retorna [] silenciosamente
    debugPrint('[CloudClinical] ⚠ Formulário vazio — sem rede e sem cache local.');
  }

  Future<List<DrugModel>?> _fetchRemote() async {
    final response = await http
        .get(Uri.parse(_remoteUrl))
        .timeout(_fetchTimeout);
    if (response.statusCode != 200) return null;
    return _parseJson(response.body);
  }

  Future<List<DrugModel>?> _readCache() async {
    if (kIsWeb) return null;
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_cacheFileName');
    if (!file.existsSync()) return null;
    return _parseJson(await file.readAsString());
  }

  Future<void> _writeCache(List<DrugModel> drugs) async {
    if (kIsWeb) return;
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      await file.writeAsString(jsonEncode(drugs.map(_modelToMap).toList()));
    } catch (e) {
      debugPrint('[CloudClinical] cache write error: $e');
    }
  }

  // ── Serialização ───────────────────────────────────────────────────────────

  List<DrugModel> _parseJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _modelFromMap(e as Map<String, dynamic>)).toList();
  }

  DrugModel _modelFromMap(Map<String, dynamic> m) {
    Map<String, String>? _strMap(dynamic v) {
      if (v == null) return null;
      return (v as Map<String, dynamic>).map((k, val) => MapEntry(k, val as String));
    }

    Map<String, List<String>>? _interactionsMap(dynamic v) {
      if (v == null) return null;
      return (v as Map<String, dynamic>)
          .map((k, val) => MapEntry(k, (val as List<dynamic>).cast<String>()));
    }

    Map<String, dynamic>? _adverseMap(dynamic v) {
      if (v == null) return null;
      return (v as Map<String, dynamic>)
          .map((k, val) => MapEntry(k, (val as List<dynamic>).cast<String>()));
    }

    return DrugModel(
      id:            m['id']       as String,
      name:          m['name']     as String,
      group:         m['group']    as String,
      route:         m['route']    as String,
      doseType:      m['doseType'] as String,
      className:     _strMap(m['className'])    ?? {},
      category:      _strMap(m['category'])     ?? {},
      fixedDose:     _strMap(m['fixedDose']),
      frequency:     _strMap(m['frequency']),
      renalAlert:    _strMap(m['renalAlert']),
      elderlyAlert:  _strMap(m['elderlyAlert']),
      mechanism:     _strMap(m['mechanism']),
      warning:       _strMap(m['warning']),
      mgKg:          (m['mgKg']          as num?)?.toDouble(),
      mcgKgMinStart: (m['mcgKgMinStart'] as num?)?.toDouble(),
      mcgKgMinMax:   (m['mcgKgMinMax']   as num?)?.toDouble(),
      adverse:       _adverseMap(m['adverse']),
      interactions:  _interactionsMap(m['interactions']),
    );
  }

  Map<String, dynamic> _modelToMap(DrugModel d) => {
    'id':       d.id,
    'name':     d.name,
    'group':    d.group,
    'route':    d.route,
    'doseType': d.doseType,
    'className': d.className,
    'category':  d.category,
    if (d.fixedDose    != null) 'fixedDose':    d.fixedDose,
    if (d.frequency    != null) 'frequency':    d.frequency,
    if (d.renalAlert   != null) 'renalAlert':   d.renalAlert,
    if (d.elderlyAlert != null) 'elderlyAlert': d.elderlyAlert,
    if (d.mechanism    != null) 'mechanism':    d.mechanism,
    if (d.warning      != null) 'warning':      d.warning,
    if (d.mgKg          != null) 'mgKg':          d.mgKg,
    if (d.mcgKgMinStart != null) 'mcgKgMinStart': d.mcgKgMinStart,
    if (d.mcgKgMinMax   != null) 'mcgKgMinMax':   d.mcgKgMinMax,
    if (d.adverse      != null) 'adverse':      d.adverse,
    if (d.interactions != null) 'interactions': d.interactions,
  };

  // ── Helpers de lookup (espelham API antiga de drugsDatabase) ───────────────

  /// Primeiro fármaco com [id] correspondente, ou null.
  DrugModel? findById(String id) {
    if (_drugs.isEmpty) return null;
    try { return _drugs.firstWhere((d) => d.id == id); } catch (_) { return null; }
  }

  /// Lista deduplicada por ID — equivalente ao antigo getter `drugsDB`.
  List<DrugModel> get uniqueDrugs {
    final seen = <String>{};
    return _drugs.where((d) => seen.add(d.id)).toList();
  }
}
