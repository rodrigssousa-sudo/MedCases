import 'dart:math';
import 'package:flutter/material.dart';
import 'admin_operations_section.dart';

class AdminNotificationsSection extends StatefulWidget {
  const AdminNotificationsSection({super.key, this.readOnly = true, this.api});
  final bool readOnly;
  final AdminOperationsApi? api;
  @override
  State<AdminNotificationsSection> createState() =>
      _AdminNotificationsSectionState();
}

class _AdminNotificationsSectionState extends State<AdminNotificationsSection> {
  late final _api = widget.api ?? AdminOperationsApi();
  final _confirmedRead = <String>{};
  List<Map<String, dynamic>> _rows = [];
  String _filter = 'UNREAD';
  String? _cursor, _nextCursor, _error;
  int _unread = 0, _epoch = 0;
  bool _loading = true, _busy = false;
  Map<String, dynamic>? _pending;
  String _requestId() => List.generate(24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.call('notificationPage', {
        'filter': _filter,
        'limit': 30,
        if (_cursor != null) 'cursor': _cursor
      });
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _rows = (result['items'] as List)
            .map((dynamic v) => Map<String, dynamic>.from(v as Map))
            .toList();
        for (final row in _rows) {
          if (_confirmedRead.contains(row['notificationId']))
            row['read'] = true;
        }
        _unread = (result['unreadCount'] as num).toInt();
        _nextCursor = result['nextCursor'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() {
          _loading = false;
          _error = 'NOTIFICATIONS_READ_FAILED';
        });
    }
  }

  Future<void> _mark({String? id, bool all = false}) async {
    if (widget.readOnly || _busy || (_pending != null && (id != null || all)))
      return;
    _pending ??= {
      'requestId': _requestId(),
      'all': all,
      if (id != null) 'notificationId': id
    };
    ++_epoch; // An older page request cannot overwrite confirmed mutation state.
    setState(() {
      _busy = true;
      _loading = false;
      _error = null;
    });
    try {
      while (_pending != null) {
        final input = Map<String, dynamic>.from(_pending!);
        final result = await _api.call('notificationRead', input);
        if (!mounted) return;
        setState(() {
          _confirmedRead.addAll(List<String>.from(result['readIds'] as List));
          for (final row in _rows) {
            if (_confirmedRead.contains(row['notificationId']))
              row['read'] = true;
          }
          _unread = (result['unreadCount'] as num).toInt();
          _pending = input['all'] == true && result['nextCursor'] != null
              ? {
                  'requestId': _requestId(),
                  'all': true,
                  'cursor': result['nextCursor']
                }
              : null;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'MARK_READ_UNCONFIRMED — tente confirmar novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        _rows.where((r) => _filter == 'ALL' || r['read'] != true).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Notificações administrativas',
          style: Theme.of(context).textTheme.headlineSmall),
      Text('Não lidas: $_unread', key: const ValueKey('unread-count')),
      const Text('Leitura por administrador. O histórico é preservado.'),
      Wrap(spacing: 12, children: [
        ChoiceChip(
            label: const Text('Não lidas'),
            selected: _filter == 'UNREAD',
            onSelected: _busy
                ? null
                : (_) {
                    _filter = 'UNREAD';
                    _cursor = null;
                    _load();
                  }),
        ChoiceChip(
            label: const Text('Todas'),
            selected: _filter == 'ALL',
            onSelected: _busy
                ? null
                : (_) {
                    _filter = 'ALL';
                    _cursor = null;
                    _load();
                  }),
        IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh)),
        if (!widget.readOnly)
          TextButton(
              onPressed: _busy || _unread == 0 || _pending != null
                  ? null
                  : () => _mark(all: true),
              child: const Text('Marcar todas como lidas')),
      ]),
      if (_error != null) Text(_error!),
      if (_pending != null && !_busy)
        TextButton(
            onPressed: () => _mark(),
            child: const Text('Confirmar leitura pendente')),
      if (_loading || _busy) const LinearProgressIndicator(),
      if (!_loading && rows.isEmpty)
        const Text('Nenhuma notificação nesta página.'),
      for (final row in rows)
        Card(
            key: ValueKey(row['notificationId']),
            child: ListTile(
                title: Text(
                    row['title'] as String? ?? 'Notificação administrativa',
                    style: TextStyle(
                        fontWeight: row['read'] == true
                            ? FontWeight.normal
                            : FontWeight.bold)),
                subtitle: Text([
                  if (row['userName'] is String &&
                      (row['userName'] as String).isNotEmpty)
                    row['userName'] as String,
                  row['read'] == true ? 'Lida' : 'Não lida'
                ].join(' · ')),
                trailing: row['read'] == true
                    ? const Chip(label: Text('Lida'))
                    : widget.readOnly
                        ? null
                        : TextButton(
                            onPressed: _busy || _pending != null
                                ? null
                                : () =>
                                    _mark(id: row['notificationId'] as String),
                            child: const Text('Marcar como lida')))),
      if (_nextCursor != null)
        TextButton(
            onPressed: _busy
                ? null
                : () {
                    _cursor = _nextCursor;
                    _load();
                  },
            child: const Text('Próxima página')),
      if (_cursor != null)
        TextButton(
            onPressed: _busy
                ? null
                : () {
                    _cursor = null;
                    _load();
                  },
            child: const Text('Primeira página')),
    ]);
  }
}
