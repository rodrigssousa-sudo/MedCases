import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_operations_section.dart';

/// Metadata projection. There is intentionally no clinical write action.
class ContentInventorySection extends StatefulWidget {
  const ContentInventorySection({super.key, required this.kind, this.api});
  final String kind;
  final AdminOperationsApi? api;
  @override
  State<ContentInventorySection> createState() =>
      _ContentInventorySectionState();
}

class _ContentInventorySectionState extends State<ContentInventorySection> {
  final _search = TextEditingController();
  final _pages = <String?>[];
  Map<String, dynamic> _result = {};
  String _filter = 'ALL';
  String? _cursor;
  String? _generation;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  AdminOperationsApi get _api => widget.api ?? AdminOperationsApi();
  static const _filters = {
    'ALL': 'Todos',
    'HAS_GAPS': 'Fila completa / todos os gaps',
    'PT_ES_COMPLETE': 'PT + ES',
    'GOLD33_COMPLETE': 'Gold33 homologado',
    'APPROVED': 'Aprovados',
    'PUBLISHED': 'Publicados',
    'PENDING': 'Pendentes / desconhecidos',
    'NEEDS_PT': 'Precisa traduzir PT',
    'NEEDS_ES': 'Precisa traduzir ES',
    'NEEDS_REVIEW': 'Sem revisão registrada',
    'NEEDS_UPDATE': 'Precisa atualizar',
    'SYNC_ERROR': 'Precisa sincronizar',
    'POSSIBLE_DUPLICATE': 'Possível duplicado',
    'CALCULATION_BLOCKED': 'Cálculo bloqueado',
    'CLINICAL_CONTENT_PENDING': 'Conteúdo sem aprovação comprovada',
    'GOLD33_INCOMPLETE': 'Gold33 incompleto',
    'NEW': 'Precisa criar',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _cursor = null;
      _generation = null;
      _pages.clear();
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await _api.call('inventory', {
        'kind': widget.kind,
        'filter': _filter,
        'search': _search.text,
        if (_cursor != null) 'cursor': _cursor,
        if (_generation != null) 'generation': _generation,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _generation = result['generation'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  String _value(dynamic v) => v == null || v == 'UNKNOWN'
      ? 'Não informado'
      : v is bool
          ? (v ? 'Sim' : 'Não')
          : '$v';
  Future<void> _history() async {
    try {
      final r = await _api
          .call('inventory', {'kind': widget.kind, 'action': 'history'});
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Histórico de sincronização'),
                content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: (r['runs'] as List? ?? [])
                                .map((dynamic run) => ListTile(
                                      title: Text(
                                          '${run['state']} · ${run['itemsRead'] ?? '—'} itens'),
                                      subtitle: Text(
                                          'Versão: ${run['sourceVersion'] ?? '—'}\nErros: ${run['errors'] ?? 0} · Divergências: ${run['mismatches'] ?? 0}'),
                                    ))
                                .toList()))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ],
              ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível consultar o histórico.')));
      }
    }
  }

  Future<void> _detail(Map<String, dynamic> row) async {
    const labels = {
      'namePt': 'Nome PT',
      'nameEs': 'Nome ES',
      'canonicalId': 'ID canônico',
      'version': 'Versão do item',
      'status': 'Estado clínico explícito',
      'authoringStatus': 'Estado de autoria na fonte',
      'publishedState': 'Publicação na fonte',
      'gold33Status': 'Gold33',
      'reviewer': 'Revisor',
      'reviewDate': 'Data de revisão',
      'reviewResult': 'Resultado da revisão',
      'calculationAuthorized': 'Cálculo autorizado',
      'publicationAuthorized': 'Publicação autorizada',
      'humanApproved': 'Aprovação humana',
      'clinicalContentApproved': 'Conteúdo clínico aprovado',
      'restrictions': 'Restrições registradas',
      'technicalMapping': 'Mapeamento técnico',
      'sourceVersion': 'Versão da fonte',
      'sourceMode': 'Modo da fonte',
      'syncStatus': 'Sincronização',
      'exactIdDuplicates': 'Mesmo ID (registros para revisão)',
      'exactNameDuplicates': 'Mesmo nome (registros para revisão)',
      'possibleAliasDuplicates': 'Aliases possíveis (registros para revisão)',
    };
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(_value(row['displayName'])),
              content: SizedBox(
                  width: 680,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text(
                            'Somente leitura. A fonte clínica permanece no repositório.'),
                        const SizedBox(height: 16),
                        for (final field in labels.entries)
                          if (row.containsKey(field.key))
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SelectableText(
                                    '${field.value}\n${_value(row[field.key])}')),
                        Text(
                            'Fila derivada: ${(row['queueReasons'] as List? ?? []).map((e) => _filters[e] ?? e).join(', ')}'),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: '${row['canonicalId']}')),
                    child: const Text('Copiar ID')),
                TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse('${row['sourceUrl']}');
                      if (uri != null &&
                          uri.scheme == 'https' &&
                          uri.host == 'github.com') { await launchUrl(uri); }
                    },
                    child: const Text('Abrir fonte')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final drugs = widget.kind == 'drugs';
    final meta = Map<String, dynamic>.from(_result['meta'] as Map? ?? {});
    final counts = Map<String, dynamic>.from(meta['counts'] as Map? ?? {});
    final rows = (_result['rows'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(
                      drugs
                          ? 'Fármacos · inventário canônico'
                          : 'Patologias · inventário canônico',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Atualizar leitura',
                  onPressed: _loading ? null : () => _load(reset: true),
                  icon: const Icon(Icons.refresh)),
              TextButton(
                  onPressed: _history, child: const Text('Histórico de sync'))
            ]),
            const Text(
                'Metadata da fonte oficial. Sem edição, aprovação ou publicação clínica pelo Admin.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in {
                'total': 'Total',
                'ptEs': 'PT + ES',
                if (drugs) 'gold33Complete': 'Gold33 homologado',
                'approved': 'Aprovados',
                'pending': 'Pendentes',
                'withoutReview': 'Sem revisão',
                'outdated': 'Desatualizados',
                'syncErrors': 'Erros de sync',
                'possibleDuplicates': 'Duplicados a revisar'
              }.entries)
                Chip(
                    label: Text('${entry.value}: ${counts[entry.key] ?? '—'}')),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: 310,
                  child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(reset: true),
                      decoration: InputDecoration(
                          labelText: 'Buscar por nome PT/ES ou ID',
                          helperText: 'Busca pelo início do nome ou ID',
                          suffixIcon: IconButton(
                              onPressed: () => _load(reset: true),
                              icon: const Icon(Icons.search))))),
              SizedBox(
                  width: 310,
                  child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText:
                              'Inventário / o que falta / fila do agente'),
                      items: _filters.entries
                          .where((e) =>
                              drugs ||
                              ![
                                'GOLD33_COMPLETE',
                                'GOLD33_INCOMPLETE',
                                'CALCULATION_BLOCKED',
                                'CLINICAL_CONTENT_PENDING'
                              ].contains(e.key))
                          .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _filter = v;
                          _load(reset: true);
                        }
                      })),
            ]),
            const SizedBox(height: 8),
            Text(
                'Sync: ${meta['syncState'] ?? 'Aguardando leitura'} · Fila derivada: ${drugs ? 'DRUG_AGENT_QUEUE' : 'PATHOLOGY_AGENT_QUEUE'}'),
            if (_filter == 'NEW')
              const Text(
                  'Nenhuma lista oficial de expansão foi validada. Não inferimos novos itens.'),
          ])),
      if (_loading) const LinearProgressIndicator(),
      if (_failed)
        Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton(
                onPressed: () => _load(),
                child: const Text(
                    'Falha ao consultar o inventário. Tentar novamente'))),
      Expanded(
          child: rows.isEmpty && !_loading
              ? const Center(child: Text('Nenhum item para este filtro.'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: ListTile(
                            onTap: () => _detail(row),
                            title: Text(_value(row['displayName'])),
                            subtitle: Text(
                                '${_value(row['nameEs'])}\n${row['canonicalId']} · PT: ${_value(row['ptAvailable'])} · ES: ${_value(row['esAvailable'])}\n${row['withoutReview'] == true ? 'Sem revisão registrada' : 'Revisão registrada'} · ${_value(row['status'])}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right)));
                  })),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(
            onPressed: _loading || _pages.isEmpty
                ? null
                : () {
                    _cursor = _pages.removeLast();
                    _load();
                  },
            child: const Text('Anterior')),
        TextButton(
            onPressed: _loading || _result['nextCursor'] == null
                ? null
                : () {
                    _pages.add(_cursor);
                    _cursor = _result['nextCursor'] as String;
                    _load();
                  },
            child: const Text('Próxima'))
      ]),
    ]);
  }
}

class ContentInventoryOverview extends StatefulWidget {
  const ContentInventoryOverview({super.key, this.api});
  final AdminOperationsApi? api;
  @override
  State<ContentInventoryOverview> createState() => _ContentInventoryOverviewState();
}
class _ContentInventoryOverviewState extends State<ContentInventoryOverview> {
  late Future<List<Map<String,dynamic>>> _data;
  @override
  void initState(){super.initState();_refresh();}
  void _refresh(){final api=widget.api??AdminOperationsApi();_data=Future.wait(['drugs','pathologies'].map((kind)=>api.call('inventory',{'kind':kind,'limit':1})));}
  @override
  Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_data,builder:(context,snapshot){
    if(snapshot.hasError)return Center(child:TextButton(onPressed:()=>setState(_refresh),child:const Text('Não foi possível carregar o inventário. Tentar novamente')));
    if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.all(24),children:[
      Row(children:[Expanded(child:Text('Conteúdo · visão canônica',style:Theme.of(context).textTheme.headlineSmall)),IconButton(onPressed:()=>setState(_refresh),tooltip:'Atualizar',icon:const Icon(Icons.refresh))]),
      const Text('O Admin acompanha as fontes oficiais. Revisão, publicação e autorização de cálculo permanecem independentes.'),
      for(var i=0;i<2;i++)Card(margin:const EdgeInsets.only(top:20),child:Padding(padding:const EdgeInsets.all(20),child:Builder(builder:(context){
        final meta=Map<String,dynamic>.from(snapshot.data![i]['meta'] as Map? ?? {}),counts=Map<String,dynamic>.from(meta['counts'] as Map? ?? {});
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(i==0?'Fármacos':'Patologias',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
          Wrap(spacing:12,runSpacing:8,children:[for(final e in {'total':'Total','ptEs':'PT + ES','approved':'Aprovados','pending':'Pendentes',if(i==0)'gold33Complete':'Gold33 homologado','withoutReview':'Sem revisão','outdated':'Desatualizados','syncErrors':'Erros de sync','possibleDuplicates':'Itens duplicados a revisar'}.entries)Chip(label:Text('${e.value}: ${counts[e.key]??'—'}'))]),
          const SizedBox(height:12),Text('Sincronização: ${meta['syncState']??'Não executada'}'),
          if(i==1)const Text('O registro identificado contém rascunhos locais; presença no inventário não significa publicação clínica.'),
          const Text('As abas de Fármacos e Patologias incluem busca, o que falta, fila derivada e histórico.'),
        ]);
      }))),
      const Padding(padding:EdgeInsets.only(top:20),child:Text('Precisa criar: nenhuma lista oficial de expansão validada. Nenhum item foi inventado ou criado automaticamente.')),
    ]);
  });
}
