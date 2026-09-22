import '../services/medcases_feature_authorization.dart';
import '../widgets/clinical_entrypoints.dart';
import '../widgets/canonical_drug_document_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drug_model.dart';
import '../providers/app_provider.dart';
import '../services/canonical_drug_library.dart';
import '../services/entitlement_service.dart';
import 'upgrade_screen.dart';
import 'calculadora_screen.dart';

/// Legacy callers supply only identity; their embedded clinical fields are not
/// rendered. The exact canonical resolver owns every displayed document.
void showDrugDetailSheet(BuildContext context, DrugModel drug,
    {FeatureEntryPoint entrypoint = FeatureEntryPoint.showDrugDetail}) {
  openDrugDetailEntry(context, drug.id);
}

class DrugsScreen extends StatefulWidget {
  const DrugsScreen({super.key, this.hideHeader = false, this.initialDrugId})
      : testLibrary = null;
  @visibleForTesting
  const DrugsScreen.forTesting(
      {super.key,
      required CanonicalDrugLibrary library,
      this.initialDrugId,
      this.hideHeader = false})
      : testLibrary = library;
  final CanonicalDrugLibrary? testLibrary;
  final bool hideHeader;
  final String? initialDrugId;
  @override
  State<DrugsScreen> createState() => _DrugsScreenState();
}

class _DrugsScreenState extends State<DrugsScreen> {
  late final EntitlementService _entitlement;
  CanonicalDrugLibrary? _library;
  String _query = '';
  String? _error;
  String? _selected;
  String? _documentOwner;
  Map<String, Object?>? _document;
  bool _busy = false;
  bool _favorites = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _entitlement =
        widget.testLibrary?.entitlement ?? EntitlementService.instance;
    _entitlement.addListener(_changed);
    _initialize();
  }

  void _changed() {
    if (!mounted) return;
    if (_selected != null &&
        (_documentOwner != _entitlement.current.resolvedUid ||
            !_entitlement.canAccessDrug(_selected!))) {
      _request++;
      _document = null;
      _selected = null;
      _busy = false;
    }
    setState(() {});
  }

  Future<void> _initialize() async {
    final p = context.read<AppProvider>();
    final prefs = await SharedPreferences.getInstance();
    final library = widget.testLibrary ??
        CanonicalDrugLibrary.runtime(
            entitlement: _entitlement,
            preferences: prefs,
            loadIndex: p.loadAiCanonicalDrugCatalog,
            loadDocument: (id) async =>
                (await p.lookupAiCanonicalDrug(id))?.source);
    await _entitlement.restoreOfflineEntitlement();
    await library.restore();
    if (!mounted) return;
    setState(() => _library = library);
    await _entitlement.refreshAuthoritativeTier();
    try {
      await library.refresh();
    } catch (_) {
      if (library.index.isEmpty)
        _error = 'Catálogo indisponível / Catálogo no disponible';
    }
    if (!mounted) return;
    setState(() {});
    if (widget.initialDrugId != null) await _open(widget.initialDrugId!);
  }

  Future<void> _open(String id) async {
    final library = _library;
    if (library == null) return;
    final authorized = await MedCasesFeatureAuthorization(_entitlement)
        .authorize(FeatureTarget.drug(id),
            entrypoint: FeatureEntryPoint.drugsScreen,
            presentPaywall: () async {
      if (mounted)
        await showUpgradeScreen(context,
            lang: context.read<AppProvider>().lang);
    });
    if (!mounted || !authorized) return;
    if (!library.index.containsKey(id)) {
      try {
        await library.refresh();
      } catch (_) {/* Exact canonical resolution stays closed. */}
    }
    if (!mounted) return;
    if (!library.allowed(id)) {
      setState(() =>
          _error = 'ID canônico indisponível / ID canónico no disponible');
      return;
    }
    final owner = _entitlement.current.resolvedUid;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = await library.lookup(id);
      if (!mounted ||
          owner != _entitlement.current.resolvedUid ||
          request != _request ||
          !library.allowed(id)) return;
      setState(() {
        _selected = id;
        _documentOwner = owner;
        _document = doc;
      });
      if (doc != null)
        await context.read<AppProvider>().registerRecent('drug', id,
            _name(library.index[id]!, context.read<AppProvider>().lang));
    } catch (_) {
      if (mounted && request == _request)
        setState(() => _error = 'Ficha indisponível / Ficha no disponible');
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  String _name(Map<String, Object?> row, String lang) {
    final name = row['name'];
    return name is Map
        ? (name[lang] ?? row['id']).toString()
        : (name ?? row['id']).toString();
  }

  Future<void> _offline() async {
    if (_library == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _library!.prepareOffline();
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Download incompleto; cache anterior preservado / Descarga incompleta; caché anterior conservada');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _request++;
    _entitlement.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final library = _library;
    if (library != null && library.index.isEmpty && _error != null) {
      // Preserve the canonical Free60/offline calculator fallback when the
      // full-catalog discovery endpoint rejects Free or is unavailable.
      return const CalculadoraScreen(
          initialUrl: 'https://medcasescalcu.com/?tab=farmacos');
    }
    final rows = library?.index.entries
            .where((e) =>
                (!_favorites || p.favDrugs.contains(e.key)) &&
                (_name(e.value, p.lang)
                        .toLowerCase()
                        .contains(_query.toLowerCase()) ||
                    e.key.contains(_query)))
            .toList() ??
        [];
    final body = Column(children: [
      TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: p.lang == 'es' ? 'Buscar fármaco' : 'Buscar fármaco')),
      Row(children: [
        FilterChip(
            label: const Text('★'),
            selected: _favorites,
            onSelected: (v) => setState(() => _favorites = v)),
        TextButton(
            onPressed: _busy ? null : _offline, child: const Text('Offline'))
      ]),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      Expanded(
          child: _document != null
              ? ListView(children: [
                  TextButton(
                      onPressed: () => setState(() {
                            _document = null;
                            _selected = null;
                          }),
                      child: const Text('←')),
                  CanonicalDrugDocumentView(
                      document: _document!, language: p.lang),
                ])
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final allowed = library!.allowed(row.key);
                    return ListTile(
                        title: Text(_name(row.value, p.lang)),
                        leading:
                            allowed ? null : const Icon(Icons.lock_outline),
                        trailing: IconButton(
                            icon: Icon(p.favDrugs.contains(row.key)
                                ? Icons.star
                                : Icons.star_border),
                            onPressed: () => p.toggleFavDrug(row.key)),
                        onTap: () => _open(row.key));
                  })),
    ]);
    return Scaffold(
        appBar: widget.hideHeader
            ? null
            : AppBar(title: Text(p.lang == 'es' ? 'Fármacos' : 'Fármacos')),
        body: SafeArea(child: body));
  }
}
