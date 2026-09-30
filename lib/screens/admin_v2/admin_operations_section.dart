import 'dart:async';
import 'dart:math';
import 'admin_visual_widgets.dart';
import 'admin_dashboard_section.dart';
import 'control_center_section.dart';
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
      this.api,
      this.creditApi});
  final String table, title;
  final bool readOnly, master;
  final AdminOperationsApi? api;
  final AdminControlApi? creditApi;
  @override
  State<AdminOperationsSection> createState() => _AdminOperationsSectionState();
}

class _AdminOperationsSectionState extends State<AdminOperationsSection> {
  late final _api = widget.api ?? AdminOperationsApi();
  final _search = TextEditingController();
  String _field = 'auto';
  String _jobType = 'transcription';
  String get _table => widget.table == 'jobs' && _jobType == 'transcription'
      ? 'transcriptions'
      : widget.table;
  String? _cursor;
  Timer? _attemptPoll;
  int _attemptPollCount = 0;
  int _pageLoads = 0;
  Map<String, dynamic>? _pending;
  bool _busy = false;
  late Future<Map<String, dynamic>> _page;
  bool get _overview => ['overview', 'health'].contains(widget.table);
  @override
  void initState() {
    super.initState();
    _load();
    _startAttemptPolling();
  }

  void _startAttemptPolling() {
    _attemptPoll?.cancel();
    _attemptPollCount = 0;
    if (widget.table == 'transcriptionAttempts') {
      _attemptPoll = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!mounted || ++_attemptPollCount > 10) {
          timer.cancel();
          return;
        }
        if (!_busy && _pageLoads == 0) _reload();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AdminOperationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table || oldWidget.title != widget.title) {
      _cursor = null;
      _search.clear();
      _pending = null;
      _load();
      _startAttemptPolling();
    }
  }

  @override
  void dispose() {
    _attemptPoll?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _pageLoads++;
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
    }).whenComplete(() => _pageLoads--);
  }

  void _reload() => setState(_load);
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
                                'Não foi possível carregar o perfil. Tente novamente.');
                          if (!s.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          final d = s.data!;
                          return SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(
                                    adminText(d['name'] ?? d['displayName'],
                                        'Usuário'),
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                                Text(adminText(d['email'])),
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, children: [
                                  AdminBadge(d['entitlementLabel']),
                                  AdminBadge(d['status'])
                                ]),
                                const SizedBox(height: 20),
                                AdminKpis({
                                  'Plano atual':
                                      adminText(d['entitlementLabel']),
                                  'Transcrição disponível':
                                      'Consultar saldo no app',
                                  'Tempo extra':
                                      adminMinutes(d['manualAvailableSeconds']),
                                  'Uso manual mensal': d['manualConsumedMs']
                                          is num
                                      ? adminMinutes(
                                          (d['manualConsumedMs'] as num) / 1000)
                                      : 'Sem dados',
                                  'Último acesso': adminDate(d['lastSeenAt']),
                                  'Dispositivos': adminText(d['deviceCount'])
                                }),
                                const SizedBox(height: 20),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  if (!widget.readOnly)
                                    FilledButton.icon(
                                        onPressed: () => _userCredits(
                                            d, 'credits',
                                            grant: true),
                                        icon: const Icon(Icons.more_time),
                                        label: const Text('Conceder tempo')),
                                  OutlinedButton(
                                      onPressed: () =>
                                          _userCredits(d, 'ledger'),
                                      child: const Text('Ver uso')),
                                  OutlinedButton(
                                      onPressed: () =>
                                          _userCredits(d, 'credits'),
                                      child: const Text('Ver histórico')),
                                  OutlinedButton(
                                      onPressed: () =>
                                          _userCredits(d, 'ledger'),
                                      child: const Text('Ver auditoria')),
                                  if (!widget.readOnly)
                                    OutlinedButton(
                                        onPressed: () => _change(
                                            d,
                                            'setUserStatus',
                                            ['approved', 'blocked', 'pending']),
                                        child: const Text('Atualizar status')),
                                  if (widget.master && !widget.readOnly)
                                    OutlinedButton(
                                        onPressed: () => _change(
                                            d,
                                            'setUserRole',
                                            ['user', 'supervisor', 'admin']),
                                        child: const Text('Permissões')),
                                  if (widget.master && !widget.readOnly) ...[
                                    OutlinedButton(
                                        onPressed: () => _access(d, false),
                                        child: const Text('Gerenciar Premium')),
                                    OutlinedButton(
                                        onPressed: () => _access(d, true),
                                        child: Text(
                                            (d['manualVipActive'] == true ||
                                                    d['isPartner'] == true)
                                                ? 'Remover VIP'
                                                : 'Conceder VIP'))
                                  ]
                                ]),
                                const SizedBox(height: 12),
                                const Text(
                                    'Premium/VIP manual é separado da assinatura paga. Remover a concessão não cancela compras nas lojas. Atualiza no próximo refresh de acesso do app (até 10 minutos).'),
                                AdminTechnical(d)
                              ]));
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'))
                ]));
  }

  Future<void> _access(Map<String, dynamic> user, bool vip) async {
    var enabled = !(vip
        ? (user['manualVipActive'] == true || user['isPartner'] == true)
        : user['manualPremiumActive'] == true);
    String reason = '';
    DateTime? expiry;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(
                        vip ? 'Gerenciar VIP' : 'Gerenciar Premium manual'),
                    content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(adminText(
                                  user['name'] ?? user['displayName'],
                                  'Usuário')),
                              Text(adminText(user['email'])),
                              SwitchListTile(
                                  title: const Text('Concessão manual ativa'),
                                  value: enabled,
                                  onChanged: (v) => update(() => enabled = v)),
                              const Text(
                                  'Não cobra nem cancela assinaturas Apple/Google. Os limites padrão do plano são preservados.'),
                              if (enabled)
                                TextButton(
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                          context: ctx,
                                          firstDate: DateTime.now()
                                              .add(const Duration(days: 1)),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 3650)));
                                      if (d != null) update(() => expiry = d);
                                    },
                                    child: Text(expiry == null
                                        ? 'Validade opcional'
                                        : adminDate(
                                            expiry!.toIso8601String()))),
                              TextField(
                                  maxLength: 500,
                                  onChanged: (v) => reason = v,
                                  decoration: const InputDecoration(
                                      labelText: 'Justificativa obrigatória'))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirmar acesso'))
                    ])));
    if (ok != true || !mounted) return;
    await _mutate({
      'action': vip ? 'setVip' : 'setManualPremium',
      'targetId': user['id'],
      'enabled': enabled,
      'reason': reason,
      if (enabled && expiry != null) 'expiresAt': expiry!.millisecondsSinceEpoch
    });
    if (mounted && _pending == null) Navigator.pop(context);
  }

  Future<void> _userCredits(Map<String, dynamic> user, String table,
      {bool grant = false}) async {
    await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
            child: SizedBox(
                width: 1000,
                height: 650,
                child: Column(children: [
                  Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close))),
                  Expanded(
                      child: ControlCenterSection(
                          table: table,
                          title: table == 'credits'
                              ? 'Tempo adicional'
                              : 'Histórico de uso',
                          readOnly: widget.readOnly,
                          initialUser: user,
                          autoOpenGrant: grant,
                          operationsApi: _api,
                          api: widget.creditApi))
                ]))));
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
                      Text(
                          'Usuário: ${adminText(row['name'] ?? row['displayName'] ?? row['email'], 'Selecionado')}'),
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: value,
                          items: choices
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text(adminLabel(v))))
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
                          isExpanded: true,
                          initialValue: event,
                          items: [
                            'NEW_FEATURE_AVAILABLE',
                            'GLOBAL_ENGAGEMENT_REMINDER'
                          ]
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(adminLabel(e))))
                              .toList(),
                          onChanged: (v) => event = v!),
                      for (final k in [
                        'ptTitle',
                        'ptBody',
                        'esTitle',
                        'esBody',
                        'destination',
                        'audience',
                        'schedule',
                        'reason'
                      ])
                        TextField(
                            onChanged: (v) => values[k] = v,
                            maxLength: k.endsWith('Title') ? 120 : 500,
                            decoration: InputDecoration(
                                labelText: const {
                              'ptTitle': 'Título PT',
                              'ptBody': 'Mensagem PT',
                              'esTitle': 'Título ES',
                              'esBody': 'Mensagem ES',
                              'destination':
                                  'Destino (Home, Feature ou deep link)',
                              'audience': 'Público pretendido',
                              'schedule': 'Agenda pretendida (opcional)',
                              'reason': 'Justificativa'
                            }[k])),
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
      'destination': values['destination'] ?? 'Home',
      'audience': values['audience'] ?? '',
      'schedule': values['schedule'] ?? '',
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
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: 'Atualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh))
        ]),
        const SizedBox(height: 8),
        if (widget.table == 'ai') ...[
          const Text(
              'Eventos históricos observados. Os modelos abaixo não definem a configuração ativa.'),
          const AdminDashboardSection(compact: true),
          DropdownButtonFormField<String>(
              isExpanded: true,
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
              })
        ],
        if (widget.table == 'users' || widget.table == 'transcriptionAttempts')
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                    width: 360,
                    child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                            labelText: 'Buscar por nome ou e-mail',
                            prefixIcon: Icon(Icons.search)),
                        onSubmitted: (_) {
                          _cursor = null;
                          _reload();
                        })),
                FilledButton(
                    onPressed: () {
                      _cursor = null;
                      _reload();
                    },
                    child: const Text('Buscar')),
                SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _field,
                        decoration:
                            const InputDecoration(labelText: 'Busca avançada'),
                        items: widget.table == 'transcriptionAttempts'
                          ? const [
                              DropdownMenuItem(
                                value: 'auto',
                                child: Text('Nome ou e-mail'),
                              ),
                              DropdownMenuItem(
                                value: 'sourceId',
                                child: Text('Fonte'),
                              ),
                              DropdownMenuItem(
                                value: 'attemptId',
                                child: Text('Tentativa'),
                              ),
                              DropdownMenuItem(
                                  value: 'jobId', child: Text('Job')),
                              DropdownMenuItem(
                                value: 'state',
                                child: Text('Estado'),
                              ),
                            ]
                          : const [
                              DropdownMenuItem(
                                value: 'auto',
                                child: Text('Nome ou e-mail'),
                              ),
                              DropdownMenuItem(
                                  value: 'uid', child: Text('UID')),
                              DropdownMenuItem(
                                value: 'status',
                                child: Text('Status'),
                              ),
                              DropdownMenuItem(
                                  value: 'plan', child: Text('Plano')),
                            ],
                      onChanged: (v) => setState(() => _field = v!)))
              ])),
        if (widget.table == 'campaigns') ...[
          const Text(
              'Campanhas bilíngues · até 3 por semana/dispositivo · envio ainda desativado'),
          if (!widget.readOnly)
            TextButton.icon(
                onPressed: _busy || _pending != null ? null : _campaign,
                icon: const Icon(Icons.add),
                label: const Text('Nova campanha'))
        ],
        if (widget.table == 'jobs')
          DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _jobType,
              items: [
                'transcription',
                'summary',
                'analysis',
                'content',
                'notification',
                'sync',
                'guide'
              ]
                  .map((v) =>
                      DropdownMenuItem(value: v, child: Text(adminLabel(v))))
                  .toList(),
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
        FutureBuilder<Map<String, dynamic>>(
            future: _page,
            builder: (context, s) {
              if (s.hasError)
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Não foi possível atualizar os dados. Tente novamente.'));
              if (!s.hasData)
                return const Padding(
                    padding: EdgeInsets.all(32),
                    child: LinearProgressIndicator());
              final d = s.data!,
                  rows = List<Map<String, dynamic>>.from(
                      ((_overview ? d['services'] : d['items']) as List? ?? [])
                          .map((x) => Map<String, dynamic>.from(x as Map)));
              final users = widget.table == 'users';
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_overview)
                      AdminKpis({
                        'Serviços saudáveis': rows
                            .where((r) => r['state'] == 'HEALTHY')
                            .length
                            .toString(),
                        'Serviços degradados': rows
                            .where((r) => r['state'] == 'DEGRADED')
                            .length
                            .toString(),
                        'Sem sinal recente': rows
                            .where((r) => r['state'] == 'UNKNOWN')
                            .length
                            .toString()
                      }),
                    if (rows.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(children: [
                            const Icon(Icons.inbox_outlined,
                                size: 36, color: Color(0xff94a3b8)),
                            const SizedBox(height: 12),
                            Text(widget.table == 'incidents'
                                ? 'Nenhum incidente registrado.'
                                : widget.table == 'campaigns'
                                    ? 'Nenhuma campanha criada ainda.'
                                    : users
                                        ? 'Nenhum usuário neste filtro.'
                                        : 'Sem dados disponíveis'),
                            const Text(
                                'Atualize ou ajuste os filtros para consultar novamente.',
                                style: TextStyle(color: Color(0xff64748b)))
                          ])),
                    if (rows.isNotEmpty)
                      Card(
                          color: Colors.white,
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                  headingRowColor: const WidgetStatePropertyAll(
                                      Color(0xfff1f5f9)),
                                  columns: [
                                    if (users)
                                      ...[
                                        'Nome',
                                        'E-mail',
                                        'Plano',
                                        'Status',
                                        'Último acesso',
                                        'Uso',
                                        'Ações'
                                      ].map((x) => DataColumn(label: Text(x)))
                                    else
                                      ..._columns().map(
                                          (x) => DataColumn(label: Text(x)))
                                  ],
                                  rows: rows
                                      .map((r) => DataRow(
                                          cells: users
                                              ? [
                                                  DataCell(Text(adminText(
                                                      r['name'] ??
                                                          r['displayName'],
                                                      'Usuário'))),
                                                  DataCell(Text(
                                                      adminText(r['email']))),
                                                  DataCell(AdminBadge(
                                                      r['entitlementLabel'] ??
                                                          r['plan'])),
                                                  DataCell(
                                                      AdminBadge(r['status'])),
                                                  DataCell(Text(adminDate(
                                                      r['lastSeenAt']))),
                                                  DataCell(TextButton(
                                                      onPressed: () =>
                                                          _detail(r),
                                                      child: const Text(
                                                          'Ver uso'))),
                                                  DataCell(TextButton(
                                                      onPressed: () =>
                                                          _detail(r),
                                                      child: const Text('Ver')))
                                                ]
                                              : _cells(r)))
                                      .toList()))),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, children: [
                      if (_cursor != null)
                        TextButton(
                            onPressed: () {
                              _cursor = null;
                              _reload();
                            },
                            child: const Text('Primeira página')),
                      if (d['nextCursor'] != null)
                        OutlinedButton(
                            onPressed: () {
                              _cursor = d['nextCursor'] as String;
                              _reload();
                            },
                            child: const Text('Próxima página'))
                    ]),
                    AdminTechnical({
                      'source': d['source'],
                      'sourceState': d['sourceState'],
                      'total': d['total']
                    })
                  ]);
            })
      ]);
  List<String> _columns() => widget.table == 'ai'
      ? [
          'Modo',
          'Provider',
          'Modelo · histórico',
          'Latência',
          'Status',
          'Horário',
          'Detalhes'
        ]
      : widget.table == 'audit'
          ? ['Data', 'Administrador', 'Ação', 'Usuário', 'Detalhes']
          : ['pathologies', 'drugs'].contains(widget.table)
              ? [
                  'Nome',
                  'Idiomas',
                  'Versão',
                  'Status',
                  'Revisor',
                  'Atualização',
                  'Detalhes'
                ]
              : widget.table == 'incidents'
                  ? [
                      'Serviço',
                      'Ocorrência',
                      'Quantidade',
                      'Última ocorrência',
                      'Status',
                      'Ações'
                    ]
                  : ['Nome / serviço', 'Status', 'Atualização', 'Ações'];
  List<DataCell> _cells(Map<String, dynamic> r) {
    final detail = DataCell(TextButton(
        onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Detalhes'),
                    content: SizedBox(
                        width: 650,
                        child: SingleChildScrollView(child: AdminTechnical(r))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Fechar'))
                    ])),
        child: const Text('Ver metadata')));
    if (widget.table == 'ai')
      return [
        DataCell(Text(adminText(r['mode'], 'Não informado'))),
        DataCell(Text(adminText(r['provider']))),
        DataCell(Text(adminText(r['model']))),
        DataCell(Text(r['durationMs'] is num
            ? '${((r['durationMs'] as num) / 1000).toStringAsFixed(1)} s'
            : 'Sem dados')),
        DataCell(AdminBadge(r['success'] ?? r['status'])),
        DataCell(Text(adminDate(r['createdAt']))),
        detail
      ];
    if (widget.table == 'audit')
      return [
        DataCell(Text(adminDate(r['timestamp']))),
        DataCell(Text(adminText(r['actorName'], 'Administrador'))),
        DataCell(Text(adminLabel(r['action']))),
        DataCell(Text(adminText(r['targetName'], '—'))),
        detail
      ];
    if (widget.table == 'incidents')
      return [
        DataCell(Text(
            adminText(r['service'] ?? r['module'], 'Serviço não informado'))),
        DataCell(Text(RegExp(r'^HTTP[_ ]?\d{3}$')
                .hasMatch(r['errorCode']?.toString() ?? '')
            ? r['errorCode'].toString().replaceAll('_', ' ')
            : 'Ocorrência técnica')),
        DataCell(Text(adminText(r['count'] ?? r['frequency']))),
        DataCell(Text(
            adminDate(r['lastSeenAt'] ?? r['lastSeen'] ?? r['updatedAt']))),
        DataCell(AdminBadge(r['status'])),
        DataCell(Row(children: [
          detail.child,
          if (!widget.readOnly)
            TextButton(
                onPressed: () => _change(r, 'setIncidentState',
                    ['open', 'acknowledged', 'resolved']),
                child: const Text('Investigar'))
        ]))
      ];
    if (['pathologies', 'drugs'].contains(widget.table))
      return [
        DataCell(Text(adminText(r['namePt'] ?? r['nameEs']))),
        DataCell(Text([
          if (r['namePt'] != null) 'PT',
          if (r['nameEs'] != null) 'ES'
        ].join(' / '))),
        DataCell(Text(adminText(r['version']))),
        DataCell(AdminBadge(r['status'] ?? r['syncStatus'])),
        DataCell(Text(adminText(r['reviewer']))),
        DataCell(Text(adminDate(r['lastUpdated']))),
        detail
      ];
    if (_table == 'transcriptionAttempts') {
      return [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(adminText(r['userName'], 'Usuário')),
              Text(adminText(r['userEmail'])),
            ],
          ),
        ),
        DataCell(AdminBadge(r['state'])),
        DataCell(Text(adminDate(r['updatedAt'] ?? r['createdAt']))),
        detail,
      ];
    }
    return [
      DataCell(Text(adminText(
          r['namePt'] ??
              r['nameEs'] ??
              r['service'] ??
              r['title'] ??
              r['type'] ??
              r['platform'] ??
              r['provider'],
          _table == 'transcriptions' ? 'Gravação' : 'Registro'))),
      DataCell(AdminBadge(r['status'] ?? r['state'] ?? r['syncStatus'])),
      DataCell(Text(adminDate(r['updatedAt'] ??
          r['lastUpdated'] ??
          r['createdAt'] ??
          r['observedAt']))),
      DataCell(Row(children: [
        detail.child,
        if (widget.table == 'incidents' && !widget.readOnly)
          TextButton(
              onPressed: () => _change(
                  r, 'setIncidentState', ['open', 'acknowledged', 'resolved']),
              child: const Text('Investigar')),
        if (_table == 'transcriptions' &&
            !widget.readOnly &&
            r['state'] == 'retryable_error')
          TextButton(
              onPressed: () =>
                  _change(r, 'retryTranscription', ['Retomar job existente']),
              child: const Text('Retomar'))
      ]))
    ];
  }
}
