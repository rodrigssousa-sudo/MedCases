import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String adminText(dynamic value, [String fallback = 'Sem dados']) =>
    value == null || value == 'UNKNOWN' || value.toString().isEmpty
        ? fallback
        : value.toString();
String adminDate(dynamic value) {
  DateTime? d = value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : DateTime.tryParse(value?.toString() ?? '');
  if (d == null) return 'Não informado';
  d = d.toLocal();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String adminMinutes(dynamic seconds) =>
    seconds is num ? '${(seconds / 60).toStringAsFixed(1)} min' : 'Sem dados';
String adminLabel(dynamic value) =>
    const <String, String>{
      'SYNCED': 'Sincronizado',
      'PUBLISHED': 'Publicado',
      'APPROVED': 'Aprovado',
      'DRAFT': 'Rascunho',
      'CANCELLED': 'Cancelado',
      'REQUESTED': 'Solicitado',
      'UPLOADING': 'Enviando',
      'PROCESSING': 'Processando',
      'COMPLETED': 'Concluído',
      'FAILED': 'Falhou',
      'RECOVERABLE_FAILED': 'Aguardando retomada',
      'PERSISTING': 'Finalizando',
      'MEDIA_UPLOAD_STARTED': 'Envio iniciado',
      'MEDIA_UPLOAD_COMPLETED': 'Envio concluído',
      'MEDIA_PROOF_FAILED': 'Falha ao verificar áudio',
      'DURATION_VERIFIED': 'Duração verificada',
      'ELIGIBILITY_CHECKED': 'Acesso verificado',
      'QUOTA_RESERVED': 'Tempo reservado',
      'JOB_CREATED': 'Processamento criado',
      'ASSEMBLYAI_SUBMITTED': 'Enviado para transcrição',
      'ASSEMBLYAI_COMPLETED': 'Transcrição concluída',
      'TRANSCRIPT_FETCHED': 'Texto recebido',
      'RESERVATION_CONSUMED': 'Consumo confirmado',
      'PUSH_CREATED': 'Notificação preparada',
      'UI_UPDATED': 'Atualização entregue',
      'ATTEMPT_CREATED': 'Tentativa registrada',
      'MEDIA_PROOF_CREATED': 'Verificação do áudio',
      'SOURCE_SAVED': 'Áudio salvo',
      'TRANSCRIPTION_REQUESTED': 'Transcrição solicitada',
      'ASSEMBLYAI_PROCESSING': 'Transcrição em processamento',
      'TRANSCRIPT_PERSISTED': 'Transcrição salva',
      'home': 'Home',
      'study': 'Estudo',
      'plantao': 'Plantão',
      'transcription': 'Transcrição',
      'summary': 'Resumo',
      'analysis': 'Análise',
      'content': 'Conteúdo',
      'notification': 'Notificação',
      'sync': 'Sincronização',
      'guide': 'Guia',
      'SUPORTE': 'Suporte',
      'SOCIO': 'Sócio',
      'EQUIPE': 'Equipe',
      'MARKETING': 'Marketing',
      'UNIVERSIDADE': 'Universidade',
      'INFLUENCER': 'Influenciador',
      'TESTE_INTERNO': 'Teste interno',
      'OUTRO': 'Outro',
      'grantManualTime': 'Tempo adicional concedido',
      'approved': 'Ativo',
      'blocked': 'Bloqueado',
      'pending': 'Pendente',
      'UNKNOWN': 'Sem dados',
      'HEALTHY': 'Saudável',
      'DEGRADED': 'Degradado',
      'FAIL': 'Falha',
      'ACTIVE': 'Disponível',
      'REVOKED': 'Revogado',
      'EXPIRED': 'Expirado',
      'EXPIRED_RESERVED': 'Expirado · reserva preservada',
      'REVOKED_RESERVED': 'Revogado · reserva preservada',
      'completed': 'Concluído',
      'retryable_error': 'Aguardando retomada',
      'terminal_error': 'Falha definitiva',
      'open': 'Aberto',
      'acknowledged': 'Em investigação',
      'resolved': 'Resolvido',
      'markNotificationRead': 'Notificação marcada como lida',
      'markAllNotificationsRead': 'Notificações marcadas como lidas',
      'grantCredit': 'Tempo adicional concedido',
      'setManualPremium': 'Premium manual atualizado',
      'setVip': 'VIP atualizado',
      'revokeCredit': 'Saldo disponível revogado',
      'setUserStatus': 'Status do usuário atualizado',
      'setUserRole': 'Permissão atualizada',
      'saveGuide': 'Guia salvo',
      'setIncidentState': 'Estado do incidente atualizado',
      'saveMaintenance': 'Manutenção atualizada',
      'saveAppUpdate': 'Aviso de atualização salvo',
      'trial': 'Trial',
      'user': 'Usuário',
      'admin': 'Administrador',
      'supervisor': 'Supervisor',
      'trialing': 'Trial',
      'inactive': 'Inativo',
      'NEW_FEATURE_AVAILABLE': 'Novo recurso',
      'GLOBAL_ENGAGEMENT_REMINDER': 'Lembrete de atividade',
      'saveCampaignDraft': 'Campanha salva como rascunho',
      'retryTranscription': 'Retomada de transcrição solicitada',
      'GRANT': 'Concessão',
      'CONSUME': 'Consumo',
      'RELEASE': 'Reserva liberada',
      'RESERVE': 'Reserva',
      'EXPIRE': 'Expiração',
      'REVOKE': 'Revogação',
      'true': 'Sucesso',
      'false': 'Falha'
    }[value?.toString()] ??
    adminText(value, 'Não informado');

class AdminBadge extends StatelessWidget {
  const AdminBadge(this.value, {super.key});
  final dynamic value;
  @override
  Widget build(BuildContext context) {
    final s = value?.toString().toLowerCase() ?? '';
    final color = [
      'healthy',
      'approved',
      'completed',
      'true',
      'active',
      'synced'
    ].contains(s)
        ? const Color(0xff167d62)
        : ['fail', 'failed', 'false', 'blocked', 'terminal_error'].contains(s)
            ? const Color(0xffbc3844)
            : ['vip', 'premium', 'pro'].contains(s)
                ? const Color(0xff6750a4)
                : ['degraded', 'pending', 'retryable_error'].contains(s)
                    ? const Color(0xff986b10)
                    : const Color(0xff64748b);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(8)),
        child: Text(adminLabel(value),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)));
  }
}

class AdminTechnical extends StatelessWidget {
  const AdminTechnical(this.data, {super.key});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => ExpansionTile(
          title:
              const Text('Detalhes técnicos', style: TextStyle(fontSize: 13)),
          children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(data))),
            if (data['id'] != null)
              TextButton.icon(
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: data['id'].toString())),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar UID'))
          ]);
}

class AdminKpis extends StatelessWidget {
  const AdminKpis(this.items, {super.key});
  final Map<String, String> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1100
            ? 6
            : c.maxWidth > 620
                ? 3
                : 2;
        final width = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items.entries
                .map((e) => Container(
                    width: width,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xffe4e9ef))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text(e.value,
                              style: TextStyle(
                                  fontSize: e.value.length > 18 ? 16 : 25,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xff172033)))
                        ])))
                .toList());
      });
}

class AdminChart extends StatelessWidget {
  const AdminChart(
      {super.key,
      required this.title,
      required this.values,
      this.caption = ''});
  final String title, caption;
  final Map<String, double> values;
  @override
  Widget build(BuildContext context) {
    final max = values.values.fold<double>(0, (a, b) => a > b ? a : b);
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe4e9ef))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (caption.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(caption,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff64748b)))),
          const SizedBox(height: 20),
          if (values.isEmpty)
            const SizedBox(
                height: 100,
                child: Center(
                    child: Text('Dados insuficientes',
                        style: TextStyle(color: Color(0xff64748b)))))
          else
            SizedBox(
                height: 140,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: values.entries
                        .map((e) => Expanded(
                            child: Tooltip(
                                message: '${e.key}: ${e.value}',
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                          e.value == e.value.roundToDouble()
                                              ? e.value.toInt().toString()
                                              : e.value.toStringAsFixed(2),
                                          style: const TextStyle(fontSize: 10)),
                                      const SizedBox(height: 5),
                                      Container(
                                          height: max == 0
                                              ? 2
                                              : (e.value / max) * 90 + 2,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 3),
                                          decoration: BoxDecoration(
                                              color: const Color(0xff147d73),
                                              borderRadius:
                                                  BorderRadius.circular(4))),
                                      const SizedBox(height: 8),
                                      Text(e.key,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10))
                                    ]))))
                        .toList()))
        ]));
  }
}

Future<Map<String, dynamic>?> pickAdminUser(
    BuildContext context,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
        call) async {
  String query = '';
  List<Map<String, dynamic>> rows = [];
  bool busy = false;
  String? error;
  return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
                  title: const Text('Selecionar usuário'),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            onChanged: (v) => query = v,
                            decoration: const InputDecoration(
                                labelText: 'Buscar por nome ou e-mail')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    update(() => busy = true);
                                    try {
                                      final r = await call('page', {
                                        'table': 'users',
                                        'field': 'auto',
                                        'value': query.trim(),
                                        'limit': 20
                                      });
                                      if (ctx.mounted)
                                        update(() => rows =
                                            List<Map<String, dynamic>>.from(
                                                (r['items'] as List).map((x) =>
                                                    Map<String, dynamic>.from(
                                                        x as Map))));
                                    } catch (_) {
                                      if (ctx.mounted)
                                        update(() => error =
                                            'Não foi possível buscar. Tente novamente.');
                                    } finally {
                                      if (ctx.mounted)
                                        update(() => busy = false);
                                    }
                                  },
                            child: const Text('Buscar')),
                        if (busy) const LinearProgressIndicator(),
                        if (error != null) Text(error!),
                        for (final r in rows)
                          ListTile(
                              title: Text(adminText(
                                  r['name'] ?? r['displayName'], 'Usuário')),
                              subtitle: Text(adminText(r['email'])),
                              trailing: AdminBadge(
                                  r['entitlementLabel'] ?? r['plan']),
                              onTap: () => Navigator.pop(ctx, r))
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'))
                  ])));
}

/// Operational metadata only; never renders an arbitrary payload in the overview.
class AdminRecordDetail extends StatelessWidget {
  const AdminRecordDetail(this.data, {super.key});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final timeline =
        data['timeline'] is List ? data['timeline'] as List : const [];
    final fields = <String, String>{
      if (data['userName'] != null) 'Usuário': adminText(data['userName']),
      if (data['userEmail'] != null) 'E-mail': adminText(data['userEmail']),
      if (data['actorName'] != null)
        'Administrador': adminText(data['actorName']),
      if (data['action'] != null) 'Ação': adminLabel(data['action']),
      if (data['service'] != null) 'Serviço': adminLabel(data['service']),
      if (data['durationMs'] is num)
        'Duração': adminMinutes((data['durationMs'] as num) / 1000),
      if (data['amountSeconds'] is num)
        'Tempo': adminMinutes(data['amountSeconds']),
      if (data['category'] != null) 'Categoria': adminLabel(data['category']),
      if (data['lastStage'] != null) 'Etapa': adminLabel(data['lastStage']),
      if (data['createdAt'] != null) 'Criado em': adminDate(data['createdAt']),
      if (data['updatedAt'] != null)
        'Atualizado em': adminDate(data['updatedAt']),
      if (data['timestamp'] != null) 'Data': adminDate(data['timestamp']),
      if (data['expiresAt'] != null) 'Expira em': adminDate(data['expiresAt']),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AdminBadge(data['status'] ?? data['state'] ?? data['success']),
      const SizedBox(height: 16),
      for (final field in fields.entries)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 130,
                  child: Text(field.key,
                      style: const TextStyle(color: Color(0xff64748b)))),
              Expanded(child: SelectableText(field.value)),
            ])),
      if (timeline.isNotEmpty) ...[
        const Divider(),
        const Text('Histórico da tentativa',
            style: TextStyle(fontWeight: FontWeight.w700)),
        for (final event in timeline.whereType<Map>())
          ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18),
              title: Text(adminLabel(event['stage'] ?? event['state'])),
              subtitle: Text(adminDate(
                  event['at'] ?? event['timestamp'] ?? event['createdAt']))),
      ],
      AdminTechnical(data),
    ]);
  }
}
