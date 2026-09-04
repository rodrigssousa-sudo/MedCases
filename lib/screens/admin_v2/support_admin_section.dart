// ADMIN_V2_SUPPORT_TICKET_CENTER_V2_B_R1
// MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/support_ticket_service.dart';

class SupportAdminSection extends StatefulWidget {
  const SupportAdminSection({
    super.key,
    required this.currentAdmin,
  });

  final UserModel currentAdmin;

  @override
  State<SupportAdminSection> createState() => _SupportAdminSectionState();
}

class _SupportAdminSectionState extends State<SupportAdminSection> {
  final _searchController = TextEditingController();
  final _replyController = TextEditingController();
  final _assigneeController = TextEditingController();

  String _statusFilter = 'all';
  String? _selectedTicketId;
  String? _editStatus;
  String? _editPriority;
  bool _saving = false;
  String? _saveMessage;

  bool get _canMutate => widget.currentAdmin.isAdmin;

  static const _statuses = <String>[
    'new',
    'in_progress',
    'waiting_user',
    'resolved',
    'closed',
  ];

  static const _priorities = <String>[
    'low',
    'normal',
    'high',
    'critical',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'in_progress':
        return 'Em atendimento';
      case 'waiting_user':
        return 'Aguardando usuário';
      case 'resolved':
        return 'Resolvido';
      case 'closed':
        return 'Encerrado';
      case 'new':
      default:
        return 'Novo';
    }
  }

  String _priorityLabel(String value) {
    switch (value) {
      case 'low':
        return 'Baixa';
      case 'high':
        return 'Alta';
      case 'critical':
        return 'Crítica';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _select(SupportTicketRecord ticket) {
    setState(() {
      _selectedTicketId = ticket.ticketId;
      _editStatus = ticket.status;
      _editPriority = ticket.priority;
      _replyController.text = ticket.adminReply;
      _assigneeController.text = ticket.assignedToEmail;
      _saveMessage = null;
    });
  }

  List<SupportTicketRecord> _filter(List<SupportTicketRecord> all) {
    final query = _searchController.text.trim().toLowerCase();

    return all.where((ticket) {
      if (_statusFilter != 'all' && ticket.status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = <String>[
        ticket.ticketId,
        ticket.userName,
        ticket.userEmail,
        ticket.categoryLabel,
        ticket.message,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  int _count(List<SupportTicketRecord> all, String status) =>
      all.where((ticket) => ticket.status == status).length;

  Future<void> _save(SupportTicketRecord ticket) async {
    if (!_canMutate || _saving) return;

    setState(() {
      _saving = true;
      _saveMessage = null;
    });

    try {
      await SupportTicketService.updateTicket(
        ticketId: ticket.ticketId,
        status: _editStatus ?? ticket.status,
        priority: _editPriority ?? ticket.priority,
        assignedTo: widget.currentAdmin.displayName.toString().trim(),
        assignedToEmail: _assigneeController.text.trim(),
        adminReply: _replyController.text.trim(),
        adminActorUid: widget.currentAdmin.uid,
        adminActorEmail: widget.currentAdmin.email.toString().trim(),
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Alterações salvas.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Falha ao salvar. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportTicketRecord>>(
      stream: SupportTicketService.watchAllTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Não foi possível carregar os tickets de suporte.'),
          );
        }

        final all = snapshot.data ?? const <SupportTicketRecord>[];
        final rows = _filter(all);

        SupportTicketRecord? selected;
        if (_selectedTicketId != null) {
          for (final ticket in all) {
            if (ticket.ticketId == _selectedTicketId) {
              selected = ticket;
              break;
            }
          }
        }

        return Container(
          color: const Color(0xFFECF0F4),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suporte',
                          style: TextStyle(
                            color: Color(0xFF18202A),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Solicitações enviadas diretamente pelo MedCases Pro.',
                          style: TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_canMutate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SUPERVISOR · SOMENTE LEITURA',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _SupportMetric(
                      label: 'Novos',
                      value: _count(all, 'new'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SupportMetric(
                      label: 'Em atendimento',
                      value: _count(all, 'in_progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SupportMetric(
                      label: 'Aguardando',
                      value: _count(all, 'waiting_user'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SupportMetric(
                      label: 'Resolvidos',
                      value: _count(all, 'resolved'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SupportMetric(
                      label: 'Críticos',
                      value: all
                          .where((ticket) => ticket.priority == 'critical')
                          .length,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'Buscar ticket, usuário, categoria ou mensagem',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E7EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E7EC)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('support-filter-$_statusFilter'),
                      initialValue: _statusFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E7EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E7EC)),
                        ),
                      ),
                      items: <String>['all', ..._statuses]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 'all'
                                    ? 'Todos os status'
                                    : _statusLabel(value),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _statusFilter = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 385,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFFE2E7EC),
                            width: 0.8,
                          ),
                        ),
                        child: rows.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum ticket neste filtro.',
                                  style: TextStyle(color: Color(0xFF68727D)),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final ticket = rows[index];
                                  final active =
                                      ticket.ticketId == _selectedTicketId;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(9),
                                    onTap: () => _select(ticket),
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? const Color(0xFFEAF4F1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  ticket.ticketId,
                                                  style: const TextStyle(
                                                    color: Color(0xFF18202A),
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _statusLabel(ticket.status),
                                                style: const TextStyle(
                                                  color: Color(0xFF0D6B57),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ticket.userName.isNotEmpty
                                                ? ticket.userName
                                                : ticket.userEmail,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF3E4854),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${ticket.categoryLabel} · ${_date(ticket.createdAt)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF68727D),
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: selected == null
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0xFFE2E7EC),
                                  width: 0.8,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Selecione um ticket para ver os detalhes.',
                                  style: TextStyle(color: Color(0xFF68727D)),
                                ),
                              ),
                            )
                          : _detail(selected),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detail(SupportTicketRecord ticket) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE2E7EC),
          width: 0.8,
        ),
      ),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.ticketId,
                  style: const TextStyle(
                    color: Color(0xFF18202A),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _date(ticket.createdAt),
                style: const TextStyle(
                  color: Color(0xFF68727D),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${ticket.userName} · ${ticket.userEmail}',
            style: const TextStyle(
              color: Color(0xFF68727D),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${ticket.categoryLabel} · ${ticket.platform} · ${ticket.locale.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFF68727D),
              fontSize: 11,
            ),
          ),
          if (ticket.rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= ticket.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFC9932E),
                    size: 17,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 15),
          const Text(
            'Mensagem do usuário',
            style: TextStyle(
              color: Color(0xFF18202A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            ticket.message,
            style: const TextStyle(
              color: Color(0xFF303945),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E7EC)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'support-status-${ticket.ticketId}-${_editStatus ?? ticket.status}',
                  ),
                  initialValue: _editStatus ?? ticket.status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _statuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _canMutate
                      ? (value) => setState(() => _editStatus = value)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'support-priority-${ticket.ticketId}-${_editPriority ?? ticket.priority}',
                  ),
                  initialValue: _editPriority ?? ticket.priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _priorities
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_priorityLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _canMutate
                      ? (value) => setState(() => _editPriority = value)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _assigneeController,
            enabled: _canMutate,
            decoration: const InputDecoration(
              labelText: 'Responsável / e-mail',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _replyController,
            enabled: _canMutate,
            minLines: 4,
            maxLines: 8,
            maxLength: 1200,
            decoration: const InputDecoration(
              labelText: 'Resposta ao usuário',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_saveMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _saveMessage!,
              style: TextStyle(
                color: _saveMessage == 'Alterações salvas.'
                    ? const Color(0xFF0D6B57)
                    : const Color(0xFFB42318),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_canMutate) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(ticket),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B57),
                  foregroundColor: Colors.white,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: const Text('Salvar atendimento'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportMetric extends StatelessWidget {
  const _SupportMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E7EC),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF18202A),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
