import 'package:flutter/material.dart';
import 'admin_operations_section.dart';
import 'admin_visual_widgets.dart';

class AdminDashboardSection extends StatefulWidget {
  const AdminDashboardSection({super.key, this.api, this.compact = false});
  final AdminOperationsApi? api;
  final bool compact;
  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  late final api = widget.api ?? AdminOperationsApi();
  late Future<Map<String, dynamic>> data;
  int days = 7;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = api.call('metrics', {
      'days': days,
      'offsetMinutes': DateTime.now().timeZoneOffset.inMinutes
    });
  }

  String n(dynamic x) => x is num
      ? (x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1))
      : 'Sem dados';
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, s) {
        if (s.hasError)
          return ListTile(
              title: const Text('Indicadores temporariamente indisponíveis'),
              trailing: TextButton(
                  onPressed: () => setState(load),
                  child: const Text('Tentar novamente')));
        if (!s.hasData)
          return const Padding(
              padding: EdgeInsets.all(32), child: LinearProgressIndicator());
        final d = s.data!,
            series = List<Map<String, dynamic>>.from(
                (d['series'] as List? ?? [])
                    .map((x) => Map<String, dynamic>.from(x as Map))),
            rolling = d['rolling24h'] as Map?;
        Map<String, double> values(String field) => {
              for (final r in series)
                if (r[field] is num)
                  (r['date'] as String).substring(5):
                      (r[field] as num).toDouble()
            };
        final providers = List<Map<String, dynamic>>.from(
            (d['providers'] as List? ?? [])
                .map((x) => Map<String, dynamic>.from(x as Map)));
        return Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.compact ? 'Visão operacional' : 'Visão geral',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700)),
                      Text('Atualizado em ${adminDate(d['observedAt'])}',
                          style: const TextStyle(color: Color(0xff64748b)))
                    ])),
                SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 dias')),
                      ButtonSegment(value: 30, label: Text('30 dias'))
                    ],
                    selected: {
                      days
                    },
                    onSelectionChanged: (v) => setState(() {
                          days = v.first;
                          load();
                        })),
                IconButton(
                    tooltip: 'Atualizar indicadores',
                    onPressed: () => setState(load),
                    icon: const Icon(Icons.refresh))
              ]),
              const SizedBox(height: 24),
              AdminKpis({
                'Usuários totais': n(d['total']),
                'Ativos hoje': n(d['activeToday']),
                'Premium · plano declarado': n(d['premium']),
                'Free · plano declarado': n(d['free']),
                'VIP interno': n(d['vip']),
                'Trials': n(d['trials']),
                'Reservas de hoje · concluídas': n(d['transcriptionsToday']),
                'Minutos consumidos': n(d['consumedMinutes']),
                'Tempo extra concedido · min': n(d['extraMinutes']),
                'Requisições IA hoje': n(d['aiToday']),
                'Study hoje': n(d['modes']?['study']),
                'Plantão hoje': n(d['modes']?['plantao']),
                'Home hoje': n(d['modes']?['home']),
                'Custo IA hoje': 'Sem dados',
                'Custo IA · 7 dias': 'Sem dados',
                'Custo transcrição': 'Sem dados',
                'Erros IA hoje': n(d['errorsToday']),
                'Jobs falhos': n(d['failedJobs']),
                'Incidentes abertos': n(d['openIncidents']),
                'Latência média IA hoje': d['aiLatencyMs'] is num
                    ? '${((d['aiLatencyMs'] as num) / 1000).toStringAsFixed(1)} s'
                    : 'Sem dados',
                'Sucesso IA · últimas 24h': rolling?['successRate'] is num
                    ? '${((rolling!['successRate'] as num) * 100).toStringAsFixed(1)}%'
                    : 'Sem dados',
                'Custo estimado IA · últimas 24h': rolling?['cost'] is num
                    ? 'US\$ ${(rolling!['cost'] as num).toStringAsFixed(3)}'
                    : 'Sem dados'
              }),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                final width =
                    c.maxWidth > 900 ? (c.maxWidth - 20) / 2 : c.maxWidth;
                final charts = <Widget>[
                  const AdminChart(
                      title: 'Usuários ativos',
                      values: {},
                      caption: 'Histórico diário ainda não disponível'),
                  AdminChart(
                      title: 'Crescimento de usuários',
                      values: values('growth'),
                      caption: 'Novos cadastros por dia'),
                  AdminChart(
                      title: 'Premium vs Free',
                      values: {
                        if (d['premium'] is num)
                          'Premium': (d['premium'] as num).toDouble(),
                        if (d['free'] is num)
                          'Free': (d['free'] as num).toDouble()
                      },
                      caption: 'Plano declarado; VIP é uma condição separada'),
                  AdminChart(
                      title: 'Consumo de transcrição',
                      values: values('consumedMinutes'),
                      caption:
                          'Minutos concluídos · agrupados pela data da reserva'),
                  AdminChart(
                      title: 'Uso de IA',
                      values: values('requests'),
                      caption: 'Requisições por dia · eventos observados'),
                  AdminChart(
                      title: 'Home / Study / Plantão',
                      values: {
                        for (final e in (d['modes'] as Map? ?? {}).entries)
                          if (e.value is num)
                            adminText(e.key): (e.value as num).toDouble()
                      },
                      caption: 'Hoje · somente eventos com modo informado'),
                  AdminChart(
                      title: 'Custo por provider / modelo',
                      values: {
                        for (final p in providers)
                          if (p['cost'] is num)
                            '${p['provider']}': (p['cost'] as num).toDouble()
                      },
                      caption:
                          'Estimativa USD · últimas 24h · não representa routing ativo'),
                  const AdminChart(
                      title: 'Custo acumulado',
                      values: {},
                      caption: 'Série diária verificada indisponível'),
                  const AdminChart(
                      title: 'Falhas por serviço',
                      values: {},
                      caption: 'Sem série histórica verificada'),
                  const AdminChart(
                      title: 'Transcrições concluídas vs falhas',
                      values: {},
                      caption: 'Sem agregado de conclusão verificado')
                ];
                return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: charts
                        .map((w) => SizedBox(width: width, child: w))
                        .toList());
              }),
              const SizedBox(height: 24),
              if (providers.isNotEmpty) ...[
                const Text('Histórico por provider · últimas 24h',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final p in providers)
                  ListTile(
                      title: Text(
                          '${adminText(p['provider'])} · ${adminText(p['model'])}'),
                      subtitle: Text(
                          '${n(p['requests'])} requisições · ${n(p['inputTokens'])} tokens entrada · ${n(p['outputTokens'])} saída'))
              ],
              AdminTechnical({
                'observedAt': d['observedAt'],
                'limitations': d['limitations'],
                'timezoneOffsetMinutes': d['timezoneOffsetMinutes']
              })
            ]));
      });
}
