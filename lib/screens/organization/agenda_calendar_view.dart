import 'organization_presentation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/organization/agenda_event.dart';

class AgendaCalendarView extends StatelessWidget {
  const AgendaCalendarView(
      {super.key,
      required this.isEs,
      required this.view,
      required this.selected,
      required this.events,
      required this.onSelect,
      required this.onOpenDay,
      required this.onEdit});
  final bool isEs;
  final int view;
  final DateTime selected;
  final List<AgendaEvent> events;
  final ValueChanged<DateTime> onSelect, onOpenDay;
  final ValueChanged<AgendaEvent> onEdit;
  String get locale => isEs ? 'es' : 'pt';
  String t(String pt, String es) => isEs ? es : pt;
  List<(AgendaEvent, DateTime)> onDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day),
        end = DateTime(day.year, day.month, day.day + 1);
    return [
      for (final e in events)
        for (final d in e.occurrences(start, end)) (e, d)
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }

  Widget eventTile(BuildContext context, (AgendaEvent, DateTime) occurrence) {
    final e = occurrence.$1;
    final colors = Theme.of(context).colorScheme;
    final label = (isEs
        ? ['Guardia', 'Estudio', 'Clase', 'Consulta', 'Personal', 'Otro']
        : [
            'Plantão',
            'Estudo',
            'Aula',
            'Consulta',
            'Pessoal',
            'Outro'
          ])[AgendaEvent.categories.indexOf(e.category)];
    return InkWell(
      onTap: () => onEdit(e),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .25)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 58,
              child: Text(DateFormat.Hm(locale).format(occurrence.$2),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600))),
          Container(
              width: 3,
              height: 38,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(3))),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(e.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('$label${e.notes.isEmpty ? '' : ' · ${e.notes}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ])),
        ]),
      ),
    );
  }

  Widget timeline(BuildContext context, DateTime day, {bool compact = false}) {
    final occurrences = onDay(day);
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return ListView(padding: EdgeInsets.all(compact ? 8 : 16), children: [
      if (!compact && occurrences.isEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Icon(Icons.event_available_outlined,
                  color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        t('Nenhum compromisso neste dia',
                            'Sin compromisos este día'),
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                        t('Adicione um compromisso para começar.',
                            'Agregá un compromiso para empezar.'),
                        style: Theme.of(context).textTheme.bodySmall)
                  ]))
            ])),
      for (var hour = 0; hour < 24; hour++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: compact ? 36 : 46,
              child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('${hour.toString().padLeft(2, '0')}:00',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant)))),
          Expanded(
              child: Container(
                  constraints: BoxConstraints(minHeight: compact ? 38 : 46),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: colors.outlineVariant
                                  .withValues(alpha: .3)))),
                  child: Column(children: [
                    if (DateUtils.isSameDay(day, now) && hour == now.hour)
                      Semantics(
                          label: t('Hora atual', 'Hora actual'),
                          child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Divider(
                                  height: 1,
                                  thickness: 2,
                                  color: colors.primary))),
                    ...occurrences
                        .where((e) => e.$2.hour == hour)
                        .map((e) => eventTile(context, e)),
                  ])))
        ])
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateTime.now();
    if (view == 1) {
      final monday = DateTime(
          selected.year, selected.month, selected.day - selected.weekday + 1);
      return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (i) {
                final day = DateTime(monday.year, monday.month, monday.day + i);
                final chosen = DateUtils.isSameDay(day, selected);
                return Container(
                    width: 210,
                    decoration: BoxDecoration(
                        border: Border(
                            right: BorderSide(
                                color: colors.outlineVariant
                                    .withValues(alpha: .3)))),
                    child: Column(children: [
                      TextButton(
                          style: TextButton.styleFrom(
                              foregroundColor: chosen
                                  ? colors.onPrimary
                                  : DateUtils.isSameDay(day, today)
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                              backgroundColor:
                                  chosen ? colors.primary : Colors.transparent),
                          onPressed: () => onOpenDay(day),
                          child: Text(DateFormat('EEE d', locale).format(day))),
                      Expanded(child: timeline(context, day, compact: true))
                    ]));
              })));
    }
    if (view == 2) {
      final first = DateTime(selected.year, selected.month);
      final days = DateTime(selected.year, selected.month + 1, 0).day;
      final offset = first.weekday - 1;
      final cells = ((offset + days) / 7).ceil() * 7;
      final selectedEvents = onDay(selected);
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(children: [
                  Row(
                      children: List.generate(
                          7,
                          (i) => Expanded(
                              child: Center(
                                  child: Text(
                                      (isEs
                                          ? [
                                              'Lun',
                                              'Mar',
                                              'Mié',
                                              'Jue',
                                              'Vie',
                                              'Sáb',
                                              'Dom'
                                            ]
                                          : [
                                              'Seg',
                                              'Ter',
                                              'Qua',
                                              'Qui',
                                              'Sex',
                                              'Sáb',
                                              'Dom'
                                            ])[i],
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color:
                                                  colors.onSurfaceVariant)))))),
                  const SizedBox(height: 8),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7, mainAxisExtent: 48),
                      itemCount: cells,
                      itemBuilder: (ctx, i) {
                        final day = DateTime(
                            selected.year, selected.month, i - offset + 1);
                        final has = onDay(day).isNotEmpty;
                        final chosen = DateUtils.isSameDay(day, selected);
                        final current = DateUtils.isSameDay(day, today);
                        final foreground = chosen
                            ? colors.onPrimary
                            : day.month != selected.month
                                ? colors.onSurfaceVariant.withValues(alpha: .5)
                                : current
                                    ? colors.primary
                                    : colors.onSurface;
                        return Padding(
                            padding: const EdgeInsets.all(2),
                            child: Semantics(
                                label:
                                    '${DateFormat.yMMMMd(locale).format(day)}${has ? t(', com compromissos', ', con compromisos') : ''}',
                                selected: chosen,
                                button: true,
                                child: TextButton(
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor: foreground,
                                        backgroundColor: chosen
                                            ? colors.primary
                                            : Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24))),
                                    onPressed: () => onSelect(day),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('${day.day}',
                                              style: TextStyle(
                                                  fontWeight: chosen || current
                                                      ? FontWeight.w700
                                                      : FontWeight.normal)),
                                          const SizedBox(height: 3),
                                          Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: has
                                                      ? (chosen
                                                          ? colors.onPrimary
                                                          : colors.primary)
                                                      : Colors.transparent))
                                        ]))));
                      }),
                ])),
            Divider(
                height: 28,
                color: colors.outlineVariant.withValues(alpha: .35)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          DateFormat('EEEE, d MMM', locale).format(selected),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600))),
                  Text('${selectedEvents.length}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ])),
            if (selectedEvents.isEmpty)
              OrganizationSurface(
                  child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest
                            .withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.event_available_outlined,
                        color: colors.onSurfaceVariant, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t('Seu dia, no seu ritmo', 'Tu día, a tu ritmo'),
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                          t('Nenhum compromisso nesta data.',
                              'Sin compromisos en esta fecha.'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ])),
              ])),
            ...selectedEvents.map((e) => eventTile(context, e)),
            const SizedBox(height: 24),
            Text(t('Próximos compromissos', 'Próximos compromisos'),
                style: Theme.of(context).textTheme.titleMedium),
            ...[
              for (var i = 0; i < 7; i++)
                ...onDay(DateTime.now().add(Duration(days: i)))
            ].take(10).map((e) => eventTile(context, e)),
          ]);
    }
    return timeline(context, selected);
  }
}
