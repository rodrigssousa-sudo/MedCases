import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminOperationsApi {
  Future<Map<String, dynamic>> call(
      String operation, Map<String, dynamic> payload) async {
    final r = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('adminOperations')
        .call<dynamic>({'operation': operation, 'payload': payload});
    return Map<String, dynamic>.from(r.data as Map);
  }
}

class AdminOperationsSection extends StatefulWidget {
  const AdminOperationsSection(
      {super.key,
      required this.table,
      required this.title,
      this.readOnly = true,
      this.master = false,
      this.api});
  final String table, title;
  final bool readOnly, master;
  final AdminOperationsApi? api;
  @override
  State<AdminOperationsSection> createState() => _AdminOperationsSectionState();
}

class _AdminOperationsSectionState extends State<AdminOperationsSection> {
  late final _api = widget.api ?? AdminOperationsApi();
  final _search = TextEditingController();
  String _field = 'email';
  String _jobType = 'transcription';
  String get _table => widget.table == 'jobs' && _jobType == 'transcription'
      ? 'transcriptions'
      : widget.table;
  String? _cursor;
  Map<String, dynamic>? _pending;
  bool _busy = false;
  late Future<Map<String, dynamic>> _page;
  bool get _overview => ['overview', 'health'].contains(widget.table);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminOperationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table || oldWidget.title != widget.title) {
      _cursor = null;
      _search.clear();
      _pending = null;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _page = _api.call(_overview ? 'overview' : 'page', {
      'table': _table,
      if (widget.table == 'jobs' && _jobType != 'transcription') ...{
        'field': 'type',
        'value': _jobType
      },
      'limit': 30,
      if (_cursor != null) 'cursor': _cursor,
      if (_search.text.trim().isNotEmpty) ...{
        'field': _field,
        'value': _search.text.trim()
      }
    });
  }

  void _reload() => setState(_load);
  String _text(dynamic x) => x == null ? 'UNKNOWN' : x.toString();
  Future<void> _detail(Map<String, dynamic> row) async {
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Detalhe operacional'),
                content: SizedBox(
                    width: 650,
                    child: FutureBuilder<Map<String, dynamic>>(
                        future: _api.call('detail', {'userId': row['id']}),
                        builder: (context, s) {
                          if (s.hasError)
                            return const Text(
                                'USER_DETAIL_UNAVAILABLE — tente novamente.');
                          if (!s.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          return SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: s.data!.entries
                                      .map((e) => SelectableText(
                                          '${e.key}: ${_text(e.value)}'))
                                      .toList()));
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'))
                ]));
  }

  Future<void> _change(
      Map<String, dynamic> row, String action, List<String> choices) async {
    String reason = '', value = choices.first;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: const Text('Alteração administrativa'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Destino: ${row['id']}'),
                      DropdownButtonFormField<String>(
                          initialValue: value,
                          items: choices
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => update(() => value = v!)),
                      TextField(
                          onChanged: (v) => reason = v,
                          decoration: const InputDecoration(
                              labelText: 'Justificativa obrigatória'),
                          maxLength: 500)
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirmar'))
                    ])));
    if (ok != true || !mounted) return;
    if (reason.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Informe uma justificativa com pelo menos 5 caracteres.')));
      return;
    }
    await _mutate({
      'targetId': row['id'],
      'action': action,
      'value': value,
      'reason': reason.trim()
    });
  }

  Future<void> _campaign() async {
    final values = <String, String>{};
    String event = 'NEW_FEATURE_AVAILABLE';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Novo rascunho PT/ES — sem envio'),
                content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: event,
                          items: [
                            'NEW_FEATURE_AVAILABLE',
                            'GLOBAL_ENGAGEMENT_REMINDER'
                          ]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => event = v!),
                      for (final k in [
                        'ptTitle',
                        'ptBody',
                        'esTitle',
                        'esBody',
                        'reason'
                      ])
                        TextField(
                            onChanged: (v) => values[k] = v,
                            maxLength: k.endsWith('Title') ? 120 : 500,
                            decoration: InputDecoration(labelText: k)),
                      const Text(
                          'Limite 3/semana/dispositivo; opt-out, silêncio e idioma obrigatórios. Disparo desativado.'),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Salvar rascunho'))
                ]));
    if (ok != true || !mounted) return;
    await _mutate({
      'action': 'saveCampaignDraft',
      'targetId': DateTime.now().microsecondsSinceEpoch.toString(),
      'eventType': event,
      'reason': values['reason'] ?? '',
      'pt': {'title': values['ptTitle'] ?? '', 'body': values['ptBody'] ?? ''},
      'es': {'title': values['esTitle'] ?? '', 'body': values['esBody'] ?? ''}
    });
  }

  Future<void> _mutate(Map<String, dynamic> data) async {
    if (_busy || (_pending != null && data.isNotEmpty)) return;
    _pending ??= {
      ...data,
      'requestId': List.generate(
          24,
          (_) => Random.secure()
              .nextInt(256)
              .toRadixString(16)
              .padLeft(2, '0')).join()
    };
    setState(() => _busy = true);
    try {
      await _api.call('mutate', _pending!);
      _pending = null;
      if (mounted) _reload();
    } on FirebaseFunctionsException catch (e) {
      if ([
        'permission-denied',
        'invalid-argument',
        'not-found',
        'already-exists',
        'unauthenticated'
      ].contains(e.code)) _pending = null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operação não confirmada: ${e.code}.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Falha de rede. Confirme a mesma operação para evitar duplicidade.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [
          Expanded(
              child: Text(widget.title,
                  style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(
              tooltip: 'Atualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh))
        ]),
        const Text(
            'Metadados operacionais. Ausência de fonte ou sinal verificado é apresentada como UNKNOWN.'),
        if (['pathologies', 'drugs'].contains(widget.table))
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'Somente leitura da fonte canônica. Sem upload, publicação clínica ou autorização de cálculo por este painel.')),
        if (widget.table == 'campaigns')
          const Text(
              'Rascunhos PT/ES; envio desativado até integração verificada de opt-out, horário silencioso e limite de 3 por semana/dispositivo.'),
        if (widget.table == 'jobs')
          const Text(
              'Inspeção de metadados. Ações de execução ficam indisponíveis quando o owner do job não fornece contrato administrativo idempotente.'),
        if (widget.table == 'campaigns' && !widget.readOnly)
          TextButton(
              onPressed: _busy || _pending != null ? null : _campaign,
              child: const Text('Novo rascunho PT/ES')),
        if (widget.table == 'jobs')
          DropdownButtonFormField<String>(
              initialValue: _jobType,
              items: [
                'transcription',
                'summary',
                'analysis',
                'content',
                'notification',
                'sync',
                'guide'
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) {
                _jobType = v!;
                _cursor = null;
                _reload();
              }),
        if (_pending != null)
          ListTile(
              title: const Text('Confirmação pendente'),
              trailing: TextButton(
                  onPressed: _busy ? null : () => _mutate({}),
                  child: const Text('Confirmar resultado'))),
        if (widget.table == 'ai')
          DropdownButtonFormField<String>(
              items: ['home', 'study', 'plantao']
                  .map((v) =>
                      DropdownMenuItem(value: v, child: Text(v.toUpperCase())))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Modo'),
              onChanged: (v) {
                _field = 'mode';
                _search.text = v!;
                _cursor = null;
                _reload();
              }),
        if (widget.table == 'users')
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Wrap(spacing: 16, runSpacing: 12, children: [
                SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                        initialValue: _field,
                        items: ['uid', 'email', 'name', 'status', 'plan']
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) => setState(() => _field = v!))),
                SizedBox(
                    width: 380,
                    child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                            labelText:
                                'Busca exata — UID, email, nome, status ou plano'),
                        onSubmitted: (_) {
                          _cursor = null;
                          _reload();
                        })),
                FilledButton(
                    onPressed: () {
                      _cursor = null;
                      _reload();
                    },
                    child: const Text('Buscar'))
              ])),
        FutureBuilder<Map<String, dynamic>>(
            future: _page,
            builder: (context, s) {
              if (s.hasError)
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'ADMIN_READ_UNAVAILABLE — atualize para tentar novamente.'));
              if (!s.hasData)
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              final d = s.data!,
                  rows = List<Map<String, dynamic>>.from((_overview
                          ? d['services']
                          : d['items'] as dynamic ?? <dynamic>[])
                      .map((dynamic r) => Map<String, dynamic>.from(r as Map)));
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d['metrics'] is Map) ...[
                      for (final e in (d['metrics'] as Map).entries)
                        Text('${e.key}: ${e.value}')
                    ],
                    if (_overview) Text('Usuários: ${d['users']}'),
                    if (!_overview)
                      Text(
                          'Fonte: ${d['source']} · ${d['sourceState']} · Total: ${d['total'] ?? 'UNKNOWN'}'),
                    if (rows.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'Nenhum registro disponível. Integração/estado: UNKNOWN até haver fonte verificada.')),
                    for (final row in rows)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final e in row.entries)
                                      SelectableText(
                                          '${e.key}: ${_text(e.value)}'),
                                    if (widget.table == 'users')
                                      Wrap(spacing: 8, children: [
                                        TextButton(
                                            onPressed: () => _detail(row),
                                            child: const Text('Detalhe e uso')),
                                        if (!widget.readOnly) ...[
                                          TextButton(
                                              onPressed:
                                                  _busy || _pending != null
                                                      ? null
                                                      : () => _change(row,
                                                              'setUserStatus', [
                                                            'approved',
                                                            'blocked',
                                                            'pending'
                                                          ]),
                                              child: const Text('Status')),
                                          if (widget.master)
                                            TextButton(
                                                onPressed:
                                                    _busy || _pending != null
                                                        ? null
                                                        : () => _change(row,
                                                                'setUserRole', [
                                                              'user',
                                                              'supervisor',
                                                              'admin'
                                                            ]),
                                                child: const Text('Papel'))
                                        ]
                                      ]),
                                    if (_table == 'transcriptions' &&
                                        !widget.readOnly &&
                                        row['state'] == 'retryable_error')
                                      TextButton(
                                          onPressed: _busy || _pending != null
                                              ? null
                                              : () => _change(
                                                  row,
                                                  'retryTranscription',
                                                  ['Retomar job existente']),
                                          child: const Text(
                                              'Solicitar retomada segura')),
                                    if (widget.table == 'incidents' &&
                                        !widget.readOnly)
                                      TextButton(
                                          onPressed: _busy || _pending != null
                                              ? null
                                              : () => _change(
                                                      row, 'setIncidentState', [
                                                    'open',
                                                    'acknowledged',
                                                    'resolved'
                                                  ]),
                                          child:
                                              const Text('Atualizar incidente'))
                                  ]))),
                    if (d['nextCursor'] != null)
                      TextButton(
                          onPressed: () {
                            _cursor = d['nextCursor'] as String;
                            _reload();
                          },
                          child: const Text('Próxima página')),
                    if (_cursor != null)
                      TextButton(
                          onPressed: () {
                            _cursor = null;
                            _reload();
                          },
                          child: const Text('Primeira página'))
                  ]);
            })
      ]);
}
