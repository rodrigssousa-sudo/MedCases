import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'admin_visual_widgets.dart';
import 'admin_operations_section.dart';

class AdminControlApi {
  Future<Map<String, dynamic>> call(
      String operation, Map<String, dynamic> payload) async {
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('adminControlCenter',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call<dynamic>({'operation': operation, 'payload': payload});
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class ControlCenterSection extends StatefulWidget {
  const ControlCenterSection(
      {super.key,
      required this.table,
      required this.title,
      this.readOnly = true,
      this.api,
      this.operationsApi,
      this.initialUser,
      this.autoOpenGrant = false});
  final String table, title;
  final bool readOnly;
  final AdminControlApi? api;
  final AdminOperationsApi? operationsApi;
  final Map<String, dynamic>? initialUser;
  final bool autoOpenGrant;
  @override
  State<ControlCenterSection> createState() => _ControlCenterSectionState();
}

class _ControlCenterSectionState extends State<ControlCenterSection> {
  late final AdminControlApi _api = widget.api ?? AdminControlApi();
  final _search = TextEditingController();
  Map<String, dynamic>? _selectedUser;
  late final _operations = widget.operationsApi ?? AdminOperationsApi();
  String? _cursor;
  bool _mutationBusy = false;
  Map<String, dynamic>? _pendingMutation;
  late Future<Map<String, dynamic>> _page;
  @override
  void initState() {
    super.initState();
    _selectedUser = widget.initialUser;
    _search.text = _selectedUser?['id']?.toString() ?? '';
    _load();
    if (widget.autoOpenGrant)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _grant();
      });
  }

  @override
  void didUpdateWidget(covariant ControlCenterSection old) {
    super.didUpdateWidget(old);
    if (old.table != widget.table) {
      _cursor = null;
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _page = _api.call('list', {
      'table': widget.table,
      'limit': 30,
      if (_cursor != null) 'cursor': _cursor,
      if (_search.text.trim().isNotEmpty &&
          ['credits', 'ledger'].contains(widget.table))
        'filter': {'field': 'userId', 'value': _search.text.trim()}
    }).then((result) async {
      final rows = List<Map<String, dynamic>>.from((result['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map)));
      final ids = rows
          .expand((r) => [
                r['userId'],
                r['grantedBy'],
                r['actorUid'],
                if (r['targetType'] == 'user') r['targetId']
              ])
          .whereType<String>()
          .toSet()
          .toList();
      if (ids.isNotEmpty) {
        final resolved = await _operations.call('identities', {'ids': ids});
        final people = {for (final p in resolved['items'] as List) p['id']: p};
        for (final r in rows) {
          r['userName'] = people[r['userId'] ?? r['targetId']]?['name'];
          r['userEmail'] = people[r['userId']]?['email'];
          r['actorName'] = people[r['grantedBy'] ?? r['actorUid']]?['name'];
        }
      }
      return {...result, 'items': rows};
    });
  }

  void _reload() {
    setState(_load);
  }

  Future<void> _grant() async {
    if (_selectedUser == null) {
      final user = await pickAdminUser(context, _operations.call);
      if (user == null || !mounted) return;
      setState(() {
        _selectedUser = user;
        _search.text = user['id'].toString();
      });
    }
    String uid = _selectedUser!['id'].toString(), minutes = '', reason = '';
    DateTime? expiry;
    String category = 'SUPORTE';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: const Text('Conceder tempo adicional'),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Text(
                                  'Adiciona saldo manual sem alterar o plano. Não inclua dados clínicos na justificativa.'),
                              ListTile(
                                  title: Text(adminText(
                                      _selectedUser?['name'] ??
                                          _selectedUser?['displayName'],
                                      'Usuário')),
                                  subtitle:
                                      Text(adminText(_selectedUser?['email'])),
                                  trailing: AdminBadge(
                                      _selectedUser?['entitlementLabel'] ??
                                          _selectedUser?['plan'])),
                              TextButton(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                        context: ctx,
                                        firstDate: DateTime.now()
                                            .add(const Duration(days: 1)),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 3650)));
                                    if (date != null)
                                      update(() => expiry = date);
                                  },
                                  child: Text(expiry == null
                                      ? 'Expiração opcional'
                                      : adminDate(expiry!.toIso8601String()))),
                              TextField(
                                  onChanged: (value) => minutes = value,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Minutos adicionais')),
                              DropdownButtonFormField<String>(
                                  initialValue: category,
                                  items: const [
                                    'SOCIO',
                                    'EQUIPE',
                                    'MARKETING',
                                    'UNIVERSIDADE',
                                    'INFLUENCER',
                                    'SUPORTE',
                                    'TESTE_INTERNO',
                                    'OUTRO'
                                  ]
                                      .map((v) => DropdownMenuItem(
                                          value: v, child: Text(v)))
                                      .toList(),
                                  onChanged: (v) =>
                                      update(() => category = v ?? category)),
                              TextField(
                                  onChanged: (value) => reason = value,
                                  maxLength: 500,
                                  decoration: const InputDecoration(
                                      labelText: 'Justificativa obrigatória')),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirmar concessão'))
                    ])));
    final target = uid.trim(),
        value = int.tryParse(minutes),
        why = reason.trim();
    if (confirmed != true || !mounted) return;
    if (target.isEmpty || value == null || value <= 0 || why.length < 5) {
      _notice(
          'Selecione o usuário, minutos inteiros positivos e justificativa.');
      return;
    }
    await _mutation({
      'action': 'grantCredit',
      'userId': target,
      'amountSeconds': value * 60,
      'category': category,
      'reason': why,
      if (expiry != null) 'expiresAt': expiry!.millisecondsSinceEpoch
    });
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _mutation(Map<String, dynamic> data) async {
    if (_mutationBusy) return;
    if (_pendingMutation != null && data.isNotEmpty) {
      _notice('Conclua a operação pendente antes de iniciar outra concessão.');
      return;
    }
    _pendingMutation ??= {
      ...data,
      'requestId': List.generate(
          24,
          (_) => Random.secure()
              .nextInt(256)
              .toRadixString(16)
              .padLeft(2, '0')).join()
    };
    setState(() => _mutationBusy = true);
    try {
      await _api.call('mutate', _pendingMutation!);
      _pendingMutation = null;
      if (!mounted) return;
      _notice('Operação registrada na auditoria.');
      _reload();
    } on FirebaseFunctionsException catch (e) {
      if ([
        'invalid-argument',
        'permission-denied',
        'unauthenticated',
        'not-found',
        'already-exists'
      ].contains(e.code)) {
        _pendingMutation = null;
      }
      _notice('Não foi possível confirmar: ${e.code}.');
    } catch (_) {
      _notice(
          'Confirmação pendente. Repetir usará a mesma operação, sem duplicar o tempo.');
    } finally {
      if (mounted) setState(() => _mutationBusy = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> row) async {
    String why = '';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Revogar saldo não utilizado?'),
                content: TextField(
                    onChanged: (value) => why = value,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        labelText: 'Justificativa — sem dados clínicos')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Revogar saldo disponível'))
                ]));
    final text = why;
    if (ok != true || !mounted) return;
    await _mutation(
        {'action': 'revokeCredit', 'creditId': row['id'], 'reason': text});
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(widget.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh)),
                if (widget.table == 'credits' && !widget.readOnly)
                  FilledButton.icon(
                      onPressed: _mutationBusy || _pendingMutation != null
                          ? null
                          : _grant,
                      icon: const Icon(Icons.add),
                      label: const Text('Conceder tempo'))
              ])
            ]),
        if (_pendingMutation != null)
          Card(
              child: ListTile(
                  title: const Text('Operação aguardando confirmação'),
                  subtitle: const Text(
                      'A nova tentativa conserva o identificador e não concede tempo em duplicidade.'),
                  trailing: TextButton(
                      onPressed: _mutationBusy ? null : () => _mutation({}),
                      child: const Text('Confirmar resultado')))),
        const SizedBox(height: 12),
        Text(
            widget.readOnly
                ? 'Consulta operacional · acesso somente leitura'
                : 'Operações registradas em auditoria',
            style: Theme.of(context).textTheme.bodySmall),
        if (['pathologies', 'drugs'].contains(widget.table))
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                  'Inventário da fonte canônica. Sem upload manual ou alteração clínica neste painel.')),
        if (['credits', 'ledger'].contains(widget.table)) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () async {
                final user = await pickAdminUser(context, _operations.call);
                if (user != null && mounted)
                  setState(() {
                    _selectedUser = user;
                    _search.text = user['id'].toString();
                    _cursor = null;
                    _load();
                  });
              },
              icon: const Icon(Icons.person_search),
              label: const Text('Buscar usuário por nome ou e-mail')),
          if (_selectedUser != null)
            Card(
                child: ListTile(
                    title: Text(adminText(
                        _selectedUser!['name'] ?? _selectedUser!['displayName'],
                        'Usuário')),
                    subtitle: Text(adminText(_selectedUser!['email'])),
                    trailing: AdminBadge(_selectedUser!['entitlementLabel'] ??
                        _selectedUser!['plan'])))
        ],
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
            future: _page,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          const Text(
                              'Leitura indisponível. Nenhum saldo ou contagem foi inferido.'),
                          TextButton(
                              onPressed: _reload,
                              child: const Text('Tentar novamente'))
                        ])));
              }
              final data = snap.data!,
                  rows = (data['items'] as List)
                      .map((r) => Map<String, dynamic>.from(r as Map))
                      .toList();
              if (rows.isEmpty) {
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(widget.table == 'credits'
                            ? 'Nenhum crédito adicional concedido ainda.'
                            : 'Nenhum evento neste histórico.')));
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                        color: Colors.white,
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                                columns: [
                                  for (final label in widget.table == 'audit'
                                      ? [
                                          'Data',
                                          'Administrador',
                                          'Ação',
                                          'Usuário',
                                          'Detalhes'
                                        ]
                                      : [
                                          'Usuário',
                                          'E-mail',
                                          'Tempo',
                                          'Categoria / ação',
                                          'Administrador',
                                          'Data',
                                          'Status',
                                          'Detalhes'
                                        ])
                                    DataColumn(label: Text(label))
                                ],
                                rows: rows
                                    .map((r) => DataRow(cells: [
                                          if (widget.table == 'audit') ...[
                                            DataCell(Text(
                                                adminDate(r['timestamp']))),
                                            DataCell(Text(adminText(
                                                r['actorName'],
                                                'Administrador'))),
                                            DataCell(
                                                Text(adminLabel(r['action']))),
                                            DataCell(Text(
                                                adminText(r['userName'], '—')))
                                          ] else ...[
                                            DataCell(Text(adminText(
                                                _selectedUser?['name'] ??
                                                    r['userName'],
                                                'Usuário'))),
                                            DataCell(Text(adminText(
                                                r['userEmail'] ??
                                                    _selectedUser?['email'],
                                                '—'))),
                                            DataCell(Text(adminMinutes(
                                                r['amountSeconds']))),
                                            DataCell(Text(adminLabel(
                                                r['category'] ??
                                                    r['type'] ??
                                                    r['action']))),
                                            DataCell(Text(adminText(
                                                r['actorName'],
                                                'Administrador'))),
                                            DataCell(Text(adminDate(
                                                r['grantedAt'] ??
                                                    r['timestamp']))),
                                            DataCell(AdminBadge(
                                                r['status'] ?? r['type'])),
                                          ],
                                          DataCell(Row(children: [
                                            TextButton(
                                                onPressed: () => showDialog<
                                                        void>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                            title: const Text(
                                                                'Detalhes do evento'),
                                                            content: SizedBox(width: 600, child: SingleChildScrollView(child: AdminTechnical(r))),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator
                                                                          .pop(
                                                                              ctx),
                                                                  child: const Text(
                                                                      'Fechar'))
                                                            ])),
                                                child:
                                                    const Text('Ver metadata')),
                                            if (widget.table == 'credits' &&
                                                !widget.readOnly)
                                              TextButton(
                                                  onPressed: !_mutationBusy &&
                                                          _pendingMutation ==
                                                              null &&
                                                          r['status'] ==
                                                              'ACTIVE'
                                                      ? () => _revoke(r)
                                                      : null,
                                                  child: const Text(
                                                      'Revogar disponível'))
                                          ]))
                                        ]))
                                    .toList()))),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: _cursor == null
                              ? null
                              : () {
                                  _cursor = null;
                                  _reload();
                                },
                          child: const Text('Primeira página')),
                      FilledButton(
                          onPressed: data['nextCursor'] == null
                              ? null
                              : () {
                                  _cursor = data['nextCursor'] as String;
                                  _reload();
                                },
                          child: const Text('Próxima página'))
                    ])
                  ]);
            })
      ]);
}
