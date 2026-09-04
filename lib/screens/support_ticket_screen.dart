// MEDCASES_SUPPORT_TICKET_USER_UI_V2_B_R1
// MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2
import 'package:flutter/material.dart';

import '../providers/app_provider.dart';
import '../services/support_ticket_service.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({
    super.key,
    required this.p,
    required this.dark,
  });

  final AppProvider p;
  final bool dark;

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _messageController = TextEditingController();

  String _category = 'support_help';
  int _rating = 0;
  bool _busy = false;
  String? _error;
  String? _sentTicketId;

  static const _categories = <String>[
    'support_help',
    'app_error',
    'suggestion',
    'drug_protocol',
    'subscription_account',
    'praise',
    'other',
  ];

  bool get _isEs => widget.p.lang.trim().toLowerCase().startsWith('es');

  Color get _background =>
      widget.dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);

  Color get _surface => widget.dark ? const Color(0xFF252930) : Colors.white;

  Color get _text =>
      widget.dark ? const Color(0xFFF7F8FA) : const Color(0xFF18202A);

  Color get _muted =>
      widget.dark ? const Color(0xFFAAB3BF) : const Color(0xFF66717E);

  Color get _line =>
      widget.dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

  static const _accent = Color(0xFF0D6B57);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'app_error':
        return _isEs ? 'Error en la app' : 'Erro no app';
      case 'suggestion':
        return _isEs ? 'Sugerencia' : 'Sugestão';
      case 'drug_protocol':
        return _isEs ? 'Fármaco / Protocolo' : 'Fármaco / Protocolo';
      case 'subscription_account':
        return _isEs ? 'Suscripción / Cuenta' : 'Assinatura / Conta';
      case 'praise':
        return _isEs ? 'Elogio' : 'Elogio';
      case 'other':
        return _isEs ? 'Otro' : 'Outro';
      case 'support_help':
      default:
        return _isEs ? 'Soporte / Ayuda' : 'Suporte / Ajuda';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return _isEs ? 'En atención' : 'Em atendimento';
      case 'waiting_user':
        return _isEs ? 'Esperando tu respuesta' : 'Aguardando sua resposta';
      case 'resolved':
        return _isEs ? 'Resuelto' : 'Resolvido';
      case 'closed':
        return _isEs ? 'Cerrado' : 'Encerrado';
      case 'new':
      default:
        return _isEs ? 'Nuevo' : 'Novo';
    }
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _submit() async {
    if (_busy) return;

    final uid = (widget.p.currentUser?.uid ?? '').trim();
    final message = _messageController.text.trim();

    if (uid.isEmpty) {
      setState(() {
        _error = _isEs
            ? 'Inicia sesión para enviar una solicitud.'
            : 'Entre na sua conta para enviar uma solicitação.';
      });
      return;
    }

    if (message.isEmpty) {
      setState(() {
        _error = _isEs
            ? 'Describe brevemente cómo podemos ayudarte.'
            : 'Descreva brevemente como podemos ajudar.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _sentTicketId = null;
    });

    try {
      final ticketId = await SupportTicketService.createTicket(
        userId: uid,
        userEmail: widget.p.userEmail,
        userName: widget.p.userName,
        category: _category,
        categoryLabel: _categoryLabel(_category),
        rating: _rating,
        message: message,
        locale: _isEs ? 'es' : 'pt',
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _sentTicketId = ticketId;
        _messageController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _isEs
            ? 'No fue posible enviar ahora. Inténtalo nuevamente.'
            : 'Não foi possível enviar agora. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = (widget.p.currentUser?.uid ?? '').trim();

    return Material(
      color: _background,
      child: SafeArea(
        // MEDCASES_SIDEBAR_SUPPORT_TOPSAFE_V1_B_R2
        // Physical safe inset + 12 px of canonical visual breathing room.
        minimum: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 12,
        ),
        top: false,
        child: Column(
          children: [
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _surface.withValues(alpha: widget.dark ? 0.88 : 0.94),
                border: Border(
                  bottom: BorderSide(color: _line, width: 0.7),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _isEs ? 'Cerrar' : 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: _text),
                  ),
                  Expanded(
                    child: Text(
                      _isEs ? 'Feedback y Soporte' : 'Feedback e Suporte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  Text(
                    _isEs ? '¿Cómo podemos ayudarte?' : 'Como podemos ajudar?',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isEs
                        ? 'Tu solicitud llegará directamente al equipo de MedCases Pro.'
                        : 'Sua solicitação chegará diretamente à equipe MedCases Pro.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isEs ? 'Categoría' : 'Categoria',
                    style: TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in _categories)
                        ChoiceChip(
                          label: Text(_categoryLabel(item)),
                          selected: _category == item,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = item),
                          side: BorderSide(
                            color: _category == item ? _accent : _line,
                            width: 0.8,
                          ),
                          backgroundColor: _surface,
                          selectedColor: _accent.withValues(alpha: 0.10),
                          labelStyle: TextStyle(
                            color: _category == item ? _accent : _text,
                            fontSize: 12,
                            fontWeight: _category == item
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isEs
                        ? '¿Cómo fue tu experiencia?'
                        : 'Como foi sua experiência?',
                    style: TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: const EdgeInsets.all(3),
                          onPressed: () => setState(() => _rating = i),
                          icon: Icon(
                            i <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color:
                                i <= _rating ? const Color(0xFFC9932E) : _muted,
                            size: 25,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _messageController,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: 500,
                    style: TextStyle(color: _text, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: _isEs
                          ? 'Describe el problema, duda o sugerencia...'
                          : 'Descreva o problema, dúvida ou sugestão...',
                      hintStyle: TextStyle(color: _muted),
                      filled: true,
                      fillColor: _surface,
                      counterStyle: TextStyle(color: _muted, fontSize: 11),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: _line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: _accent,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: _line, width: 0.7),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.privacy_tip_outlined,
                          color: _accent,
                          size: 17,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _isEs
                                ? 'Privacidad: no incluyas nombre, documento, imágenes ni otros datos que identifiquen a un paciente.'
                                : 'Privacidade: não inclua nome, documento, imagens ou outros dados que identifiquem um paciente.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_sentTicketId != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        _isEs
                            ? 'Solicitud enviada · ${_sentTicketId!}'
                            : 'Solicitação enviada · ${_sentTicketId!}',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isEs ? 'Enviar al soporte' : 'Enviar ao suporte',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEs ? 'Mis solicitudes' : 'Minhas solicitações',
                          style: TextStyle(
                            color: _text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.history_rounded, color: _muted, size: 18),
                    ],
                  ),
                  const SizedBox(height: 9),
                  if (uid.isEmpty)
                    Text(
                      _isEs
                          ? 'Inicia sesión para ver tus solicitudes.'
                          : 'Entre na conta para ver suas solicitações.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    )
                  else
                    StreamBuilder<List<SupportTicketRecord>>(
                      stream: SupportTicketService.watchUserTickets(uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            _isEs
                                ? 'No fue posible cargar las solicitudes.'
                                : 'Não foi possível carregar as solicitações.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        final tickets = snapshot.data!;
                        if (tickets.isEmpty) {
                          return Text(
                            _isEs
                                ? 'Aún no tienes solicitudes.'
                                : 'Você ainda não possui solicitações.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          );
                        }

                        return Column(
                          children: [
                            for (final ticket in tickets.take(5))
                              Container(
                                margin: const EdgeInsets.only(bottom: 7),
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: _line,
                                    width: 0.7,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ticket.ticketId,
                                            style: TextStyle(
                                              color: _text,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _statusLabel(ticket.status),
                                          style: const TextStyle(
                                            color: _accent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${ticket.categoryLabel} · ${_date(ticket.createdAt)}',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    if (ticket.adminReply.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _isEs
                                            ? 'Respuesta de MedCases'
                                            : 'Resposta da MedCases',
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ticket.adminReply,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 11.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
