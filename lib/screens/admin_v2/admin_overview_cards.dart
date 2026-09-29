import 'package:flutter/material.dart';
import 'admin_operations_section.dart';
import 'admin_visual_widgets.dart';

/// Aggregate summaries only. Missing sources are never interpreted as zero.
class AdminOverviewCards extends StatefulWidget {
  const AdminOverviewCards({super.key, required this.content, this.api});
  final bool content;
  final AdminOperationsApi? api;
  @override
  State<AdminOverviewCards> createState() => _AdminOverviewCardsState();
}

class _AdminOverviewCardsState extends State<AdminOverviewCards> {
  late final data = (widget.api ?? AdminOperationsApi()).call('metrics',
      {'days': 7, 'offsetMinutes': DateTime.now().timeZoneOffset.inMinutes});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, s) {
        final d = s.data ?? {}, c = d['content'] as Map? ?? {};
        return Padding(
            padding: const EdgeInsets.all(24),
            child: AdminKpis(widget.content
                ? {
                    'Guias totais': adminText(c['guides']),
                    'Patologias totais': adminText(c['pathologies']),
                    'Fármacos totais': adminText(c['drugs']),
                    'Atualizados recentemente': 'Sem dados',
                    'Erros de sincronização': 'Sem dados',
                    'Pendentes': 'Sem dados'
                  }
                : {
                    'Premium · plano declarado': adminText(d['premium']),
                    'Free · plano declarado': adminText(d['free']),
                    'Trials': adminText(d['trials']),
                    'VIP interno': adminText(d['vip'])
                  }));
      });
}
