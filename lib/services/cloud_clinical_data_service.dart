import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/drug_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CloudClinicalDataService — BUILD 324
// Serves the 628-drug formulary from a remote JSON (GitHub raw), with a
// file-based offline cache and bundled-asset fallback.
// Consumers call the same DrugModel type as before — zero UI changes needed.
// ─────────────────────────────────────────────────────────────────────────────

class CloudClinicalDataService {
  CloudClinicalDataService._();
  static final CloudClinicalDataService instance = CloudClinicalDataService._();

  static const _remoteUrl =
      'https://raw.githubusercontent.com/rodrigssousa-sudo/MedCases/main/assets/drugs_database.json';
  static const _cacheFileName = 'drugs_database_cache_v1.json';
  static const _fetchTimeout = Duration(seconds: 5);

  List<DrugModel> _drugs = const [];
  bool _loaded = false;
  bool _loading = false;

  /// Immutable snapshot of the loaded formulary.
  List<DrugModel> get drugs => _drugs;

  bool get isLoaded => _loaded;

  /// Idempotent initialisation. Safe to call multiple times.
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

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _load() async {
    // 1. Try remote fetch and update cache
    try {
      final data = await _fetchRemote();
      if (data != null && data.isNotEmpty) {
        _drugs = List.unmodifiable(data);
        _loaded = true;
        unawaited(_writeCache(data));
        debugPrint('[CloudClinical] Loaded ${_drugs.length} drugs from remote.');
        return;
      }
    } catch (_) {}

    // 2. Try local file cache
    try {
      final data = await _readCache();
      if (data != null && data.isNotEmpty) {
        _drugs = List.unmodifiable(data);
        _loaded = true;
        debugPrint('[CloudClinical] Loaded ${_drugs.length} drugs from cache.');
        return;
      }
    } catch (_) {}

    // 3. Bundled asset fallback (always available, even offline on first boot)
    try {
      final data = await _readBundledAsset();
      if (data != null && data.isNotEmpty) {
        _drugs = List.unmodifiable(data);
        _loaded = true;
        debugPrint('[CloudClinical] Loaded ${_drugs.length} drugs from bundled asset.');
        return;
      }
    } catch (_) {}

    debugPrint('[CloudClinical] WARNING: all load strategies failed — formulary empty.');
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
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_cacheFileName');
    if (!file.existsSync()) return null;
    return _parseJson(await file.readAsString());
  }

  Future<void> _writeCache(List<DrugModel> drugs) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      final rawList = drugs.map(_modelToMap).toList();
      await file.writeAsString(jsonEncode(rawList));
    } catch (e) {
      debugPrint('[CloudClinical] cache write error: $e');
    }
  }

  Future<List<DrugModel>?> _readBundledAsset() async {
    final raw = await rootBundle.loadString('assets/drugs_database.json');
    return _parseJson(raw);
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  List<DrugModel> _parseJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _modelFromMap(e as Map<String, dynamic>)).toList();
  }

  DrugModel _modelFromMap(Map<String, dynamic> m) {
    Map<String, String>? _strMap(dynamic v) {
      if (v == null) return null;
      final raw = v as Map<String, dynamic>;
      return raw.map((k, val) => MapEntry(k, val as String));
    }

    Map<String, List<String>>? _interactionsMap(dynamic v) {
      if (v == null) return null;
      final raw = v as Map<String, dynamic>;
      return raw.map((k, val) =>
          MapEntry(k, (val as List<dynamic>).cast<String>()));
    }

    Map<String, dynamic>? _adverseMap(dynamic v) {
      if (v == null) return null;
      final raw = v as Map<String, dynamic>;
      return raw.map((k, val) =>
          MapEntry(k, (val as List<dynamic>).cast<String>()));
    }

    return DrugModel(
      id:            m['id'] as String,
      name:          m['name'] as String,
      group:         m['group'] as String,
      route:         m['route'] as String,
      doseType:      m['doseType'] as String,
      className:     _strMap(m['className']) ?? {},
      category:      _strMap(m['category']) ?? {},
      fixedDose:     _strMap(m['fixedDose']),
      frequency:     _strMap(m['frequency']),
      renalAlert:    _strMap(m['renalAlert']),
      elderlyAlert:  _strMap(m['elderlyAlert']),
      mechanism:     _strMap(m['mechanism']),
      warning:       _strMap(m['warning']),
      mgKg:          (m['mgKg'] as num?)?.toDouble(),
      mcgKgMinStart: (m['mcgKgMinStart'] as num?)?.toDouble(),
      mcgKgMinMax:   (m['mcgKgMinMax'] as num?)?.toDouble(),
      adverse:       _adverseMap(m['adverse']),
      interactions:  _interactionsMap(m['interactions']),
    );
  }

  Map<String, dynamic> _modelToMap(DrugModel d) => {
    'id':           d.id,
    'name':         d.name,
    'group':        d.group,
    'route':        d.route,
    'doseType':     d.doseType,
    'className':    d.className,
    'category':     d.category,
    if (d.fixedDose != null)     'fixedDose':     d.fixedDose,
    if (d.frequency != null)     'frequency':     d.frequency,
    if (d.renalAlert != null)    'renalAlert':    d.renalAlert,
    if (d.elderlyAlert != null)  'elderlyAlert':  d.elderlyAlert,
    if (d.mechanism != null)     'mechanism':     d.mechanism,
    if (d.warning != null)       'warning':       d.warning,
    if (d.mgKg != null)          'mgKg':          d.mgKg,
    if (d.mcgKgMinStart != null) 'mcgKgMinStart': d.mcgKgMinStart,
    if (d.mcgKgMinMax != null)   'mcgKgMinMax':   d.mcgKgMinMax,
    if (d.adverse != null)       'adverse':       d.adverse,
    if (d.interactions != null)  'interactions':  d.interactions,
  };

  // ── Lookup helpers (mirrors the old drugsDatabase API exactly) ─────────────

  /// Finds first drug matching [id], or null if not loaded / not found.
  DrugModel? findById(String id) {
    if (_drugs.isEmpty) return null;
    try {
      return _drugs.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Deduplicates by ID — equivalent to the old `drugsDB` getter in AppProvider.
  List<DrugModel> get uniqueDrugs {
    final seen = <String>{};
    return _drugs.where((d) => seen.add(d.id)).toList();
  }
}
