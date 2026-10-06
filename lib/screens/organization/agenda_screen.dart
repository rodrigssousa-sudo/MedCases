import 'organization_presentation.dart';
import '../../services/entitlement_service.dart';
import '../../services/medcases_feature_authorization.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/organization/agenda_event.dart';
import '../../services/organization/device_calendar.dart';
import '../../services/organization/agenda_repository.dart';
import '../../services/organization/organization_notifications.dart';
import 'organization_timer_screen.dart';
import 'agenda_calendar_view.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.isEs, this.authorization});
  final bool isEs;
  final MedCasesFeatureAuthorization? authorization;
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    with WidgetsBindingObserver {
  late final repository = AgendaRepository(authorization: authorization);
  MedCasesFeatureAuthorization get authorization =>
      widget.authorization ?? MedCasesFeatureAuthorization.instance;
  static const agendaTarget =
      FeatureTarget.capability(MedCasesCapability.agenda);
  bool initialized = false;
  Future<void> _initialize() async {
    final granted = await authorization.authorize(agendaTarget,
        entrypoint: FeatureEntryPoint.restoredNavigation);
    if (!mounted ||
        !granted ||
        !authorization.allows(agendaTarget) ||
        initialized) {
      return;
    }
    initialized = true;
    authSub = repository.auth.authStateChanges().listen((user) {
      if (!mounted) return;
      if (owner != user?.uid) {
        owner = user?.uid;
        windowEvents.clear();
        recurringEvents.clear();
        _subscribe();
      }
    });
  }

  void _entitlementChanged() {
    if (!mounted) return;
    if (!authorization.allows(agendaTarget)) {
      generation++;
      unawaited(windowSub?.cancel());
      unawaited(recurrenceSub?.cancel());
      unawaited(authSub?.cancel());
      windowEvents.clear();
      recurringEvents.clear();
      initialized = false;
      owner = null;
      unawaited(MedCasesOrganizationNotifications.cancelRegisteredAgenda());
    }
    setState(() {});
  }

  late final alerts = MedCasesOrganizationNotifications(isEs: widget.isEs);
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? windowSub,
      recurrenceSub;
  StreamSubscription<User?>? authSub;
  Map<String, AgendaEvent> windowEvents = {}, recurringEvents = {};
  DateTime selected = DateTime.now();
  int view = 2, generation = 0;
  bool loading = true, offline = false, failed = false;
  String? owner;
  Future<void> reminderWork = Future.value();
  String t(String pt, String es) => widget.isEs ? es : pt;
  String get locale => widget.isEs ? 'es' : 'pt';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    authorization.entitlement.addListener(_entitlementChanged);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAccess());
  }

  Future<void> _refreshAccess() async {
    await authorization.entitlement.refreshAuthoritativeTier(force: true);
    if (!mounted) return;
    if (!authorization.allows(agendaTarget)) {
      _entitlementChanged();
    } else if (!initialized) {
      await _initialize();
    } else {
      _subscribe();
    }
  }

  DateTime get from => DateTime(selected.year, selected.month);
  DateTime get until => DateTime(selected.year, selected.month + 1, 8);
  void _subscribe() {
    if (!authorization.allows(agendaTarget)) {
      _entitlementChanged();
      return;
    }
    final token = ++generation;
    unawaited(windowSub?.cancel());
    unawaited(recurrenceSub?.cancel());
    setState(() {
      loading = true;
      failed = false;
    });
    final uid = owner;
    if (uid == null) {
      setState(() {
        loading = false;
        failed = true;
      });
      return;
    }
    void apply(QuerySnapshot<Map<String, dynamic>> snapshot, bool recurring) {
      if (!mounted ||
          generation != token ||
          !authorization.allows(agendaTarget) ||
          repository.auth.currentUser?.uid != uid) {
        return;
      }
      try {
        final events = {
          for (final doc in snapshot.docs)
            doc.id: AgendaEvent.fromFirestore(doc.data())
        };
        if (events.values.any((e) => e.userId != uid)) {
          throw StateError('AGENDA_OWNER_MISMATCH');
        }
        setState(() {
          if (recurring) {
            recurringEvents = events;
          } else {
            windowEvents = events;
          }
          offline = snapshot.metadata.isFromCache;
          loading = false;
        });
        if (!snapshot.metadata.hasPendingWrites &&
            !snapshot.metadata.isFromCache) {
          reminderWork = reminderWork
              .catchError((Object _) {})
              .then((_) => _reconcileReminders(uid, token))
              .catchError((Object _) {
            error();
          });
        }
      } catch (_) {
        error();
      }
    }

    windowSub = repository
        .window(uid, from, until)
        .listen((s) => apply(s, false), onError: (_) => error());
    recurrenceSub = repository
        .recurring(uid)
        .listen((s) => apply(s, true), onError: (_) => error());
  }

  void error() {
    if (mounted) {
      setState(() {
        failed = true;
        loading = false;
      });
    }
  }

  List<AgendaEvent> get events => {...windowEvents, ...recurringEvents}
      .values
      .where((e) => e.status == 'active')
      .toList();
  List<(AgendaEvent, DateTime)> onDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day),
        end = DateTime(day.year, day.month, day.day + 1);
    return [
      for (final e in events)
        for (final date in e.occurrences(start, end)) (e, date)
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }

  Future<void> _reconcileReminders(String uid, int token) async {
    if (!mounted ||
        token != generation ||
        repository.auth.currentUser?.uid != uid) {
      return;
    }
    repository.assertOwner(uid);
    final nowQuery = DateTime.now();
    final future = await repository
        .collection(uid)
        .where('startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                nowQuery.subtract(const Duration(days: 1)).toUtc()))
        .where('startAt',
            isLessThan: Timestamp.fromDate(
                nowQuery.add(const Duration(days: 32)).toUtc()))
        .orderBy('startAt')
        .limit(300)
        .get(const GetOptions(source: Source.server));
    final anchors = await repository
        .collection(uid)
        .where('recurrence', whereIn: ['daily', 'weekly', 'monthly'])
        .limit(100)
        .get(const GetOptions(source: Source.server));
    if (!mounted ||
        token != generation ||
        repository.auth.currentUser?.uid != uid) {
      return;
    }
    final reminderEvents = {
      for (final doc in [...future.docs, ...anchors.docs])
        doc.id: AgendaEvent.fromFirestore(doc.data())
    }.values.where((e) => e.status == 'active');
    final prefs = await SharedPreferences.getInstance();
    final previousOwner = prefs.getString('organization_agenda_reminder_owner');
    final old = prefs.getStringList('organization_agenda_reminder_ids') ?? [];
    if (previousOwner != uid) {
      for (final id in old) {
        await alerts.cancelAgendaReminder(id);
      }
    }
    final now = DateTime.now(),
        horizon = DateTime.now().add(const Duration(days: 31));
    final planned = <(String, DateTime, String)>[];
    for (final e in reminderEvents) {
      if (e.userId != uid || e.reminderMinutes == null) continue;
      for (final at
          in e.occurrences(now.subtract(const Duration(days: 1)), horizon)) {
        final reminder = at.subtract(Duration(minutes: e.reminderMinutes!));
        if (reminder.isAfter(now)) {
          planned.add((
            '${uid}_${e.id}_${at.millisecondsSinceEpoch}',
            reminder,
            e.title
          ));
        }
      }
    }
    planned.sort((a, b) => a.$2.compareTo(b.$2));
    // iOS caps pending notifications. Keep a rolling 40-event window, reserving room for existing features.
    final next = planned.take(40).toList();
    final ids = next.map((p) => p.$1).toSet();
    for (final id in old.where((id) => !ids.contains(id))) {
      await alerts.cancelAgendaReminder(id);
    }
    for (final item in next) {
      if (!mounted ||
          token != generation ||
          repository.auth.currentUser?.uid != uid) {
        return;
      }
      await alerts.scheduleAgendaReminder(
          id: item.$1, owner: uid, at: item.$2, title: item.$3);
    }
    if (!mounted ||
        token != generation ||
        repository.auth.currentUser?.uid != uid) {
      return;
    }
    await prefs.setString('organization_agenda_reminder_owner', uid);
    await prefs.setStringList('organization_agenda_reminder_ids', ids.toList());
  }

  @override
  void dispose() {
    authorization.entitlement.removeListener(_entitlementChanged);
    generation++;
    unawaited(windowSub?.cancel());
    unawaited(recurrenceSub?.cancel());
    unawaited(authSub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !authorization.allows(agendaTarget)
      ? Scaffold(
          appBar: organizationAppBar('Agenda'),
          body: Center(
              child: Text(t('A Agenda é uma função do MedCases Premium.',
                  'La Agenda es una función de MedCases Premium.'))))
      : Scaffold(
          appBar: organizationAppBar('Agenda'),
          floatingActionButton: FloatingActionButton(
              onPressed: owner == null ? null : () => _edit(null),
              tooltip: t('Novo compromisso', 'Nuevo compromiso'),
              child: const Icon(Icons.add)),
          body: Column(children: [
            Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<int>(
                    style: organizationSegments(context),
                    segments: [
                      ButtonSegment(value: 0, label: Text(t('Dia', 'Día'))),
                      ButtonSegment(
                          value: 1, label: Text(t('Semana', 'Semana'))),
                      ButtonSegment(value: 2, label: Text(t('Mês', 'Mes')))
                    ],
                    selected: {view},
                    onSelectionChanged: (s) =>
                        setState(() => view = s.single))),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            DateFormat(
                                    view == 2 ? 'MMMM' : 'EEE, d MMM', locale)
                                .format(selected),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.6)),
                        Text('${selected.year}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ])),
                  IconButton(
                      tooltip: t('Anterior', 'Anterior'),
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left, size: 20)),
                  IconButton(
                      tooltip: t('Próximo', 'Siguiente'),
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right, size: 20)),
                ])),
            if (offline)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t(
                      'Dados salvos no dispositivo. Sincronização ao reconectar.',
                      'Datos guardados en el dispositivo. Sincronización al reconectar.'))),
            if (failed)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.sync_problem_outlined,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                t('Não foi possível sincronizar',
                                    'No pudimos sincronizar'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer))),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                            onPressed: _subscribe,
                            child: Text(t('Tentar novamente', 'Reintentar')))
                      ]))),
            Expanded(
                child: loading && events.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _content()),
          ]));
  void _move(int delta) {
    setState(() {
      selected = view == 2
          ? DateTime(selected.year, selected.month + delta, 1)
          : DateTime(selected.year, selected.month,
              selected.day + delta * (view == 1 ? 7 : 1));
    });
    _subscribe();
  }

  Widget _content() => AgendaCalendarView(
      isEs: widget.isEs,
      view: view,
      selected: selected,
      events: events,
      onSelect: (day) => setState(() => selected = day),
      onOpenDay: (day) => setState(() {
            selected = day;
            view = 0;
          }),
      onEdit: _edit);
  Future<void> _edit(AgendaEvent? event) async {
    final uid = owner;
    if (uid == null) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AgendaEditor(
            isEs: widget.isEs,
            repository: repository,
            owner: uid,
            date: selected,
            event: event,
            alerts: alerts)));
    if (changed == true && mounted) _subscribe();
  }
}

class AgendaEditor extends StatefulWidget {
  const AgendaEditor(
      {super.key,
      required this.isEs,
      required this.repository,
      required this.owner,
      required this.date,
      required this.alerts,
      this.event});
  final bool isEs;
  final AgendaRepository repository;
  final String owner;
  final DateTime date;
  final AgendaEvent? event;
  final MedCasesOrganizationNotifications alerts;
  @override
  State<AgendaEditor> createState() => _AgendaEditorState();
}

class _AgendaEditorState extends State<AgendaEditor> {
  late final title = TextEditingController(text: widget.event?.title ?? '');
  late final notes = TextEditingController(text: widget.event?.notes ?? '');
  late DateTime date = widget.event?.startAt.toLocal() ?? widget.date;
  late TimeOfDay start = TimeOfDay.fromDateTime(
      widget.event?.startAt.toLocal() ??
          DateTime(widget.date.year, widget.date.month, widget.date.day, 9));
  late TimeOfDay? end = widget.event?.endAt == null
      ? null
      : TimeOfDay.fromDateTime(widget.event!.endAt!.toLocal());
  late bool overnight = widget.event?.endAt != null &&
      widget.event!.endAt!.toLocal().day != date.day;
  late String category = widget.event?.category ?? 'personal',
      recurrence = widget.event?.recurrence ?? 'none';
  late int? reminder = widget.event?.reminderMinutes;
  late final String id =
      widget.event?.id ?? widget.repository.collection(widget.owner).doc().id;
  late bool calendarLinked = widget.event?.deviceCalendarLinked ?? false;
  String? nativeId;
  bool firestoreConfirmed = false;
  bool busy = false;
  String? error;
  String t(String pt, String es) => widget.isEs ? es : pt;
  bool get accessAllowed => widget.repository.authorization
      .allows(const FeatureTarget.capability(MedCasesCapability.agenda));
  @override
  void initState() {
    super.initState();
    widget.repository.authorization.entitlement.addListener(_accessChanged);
  }

  void _accessChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.authorization.entitlement.removeListener(_accessChanged);
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    dismissOrganizationKeyboard();
    if (!accessAllowed || busy) return;
    final at =
        DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final until = end == null
        ? null
        : DateTime(date.year, date.month, date.day + (overnight ? 1 : 0),
            end!.hour, end!.minute);
    final event = AgendaEvent(
        id: id,
        userId: widget.owner,
        title: title.text,
        category: category,
        startAt: at,
        endAt: until,
        notes: notes.text,
        reminderMinutes: reminder,
        recurrence: recurrence,
        deviceCalendarLinked: calendarLinked,
        deviceCalendarEventId: nativeId ?? widget.event?.deviceCalendarEventId);
    try {
      event.validate();
    } catch (_) {
      setState(() => error = t('Revise título, horários e data.',
          'Revisá título, horarios y fecha.'));
      return;
    }
    setState(() => busy = true);
    try {
      if (reminder != null && mounted) {
        await organizationPermission(context, widget.alerts, widget.isEs);
      }
      await widget.repository
          .save(event, create: widget.event == null && !firestoreConfirmed)
          .timeout(const Duration(seconds: 15));
      firestoreConfirmed = true;
      widget.repository.assertOwner(widget.owner);
      if (calendarLinked) {
        nativeId =
            await OrganizationDeviceCalendar().save(event, isEs: widget.isEs);
        final linked = AgendaEvent(
            id: event.id,
            userId: event.userId,
            title: event.title,
            category: event.category,
            startAt: event.startAt,
            endAt: event.endAt,
            notes: event.notes,
            reminderMinutes: event.reminderMinutes,
            recurrence: event.recurrence,
            deviceCalendarLinked: true,
            deviceCalendarEventId: nativeId);
        await widget.repository
            .save(linked, create: false)
            .timeout(const Duration(seconds: 15));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => error = t(
            'Não foi possível confirmar o salvamento. O formulário foi preservado; tente novamente com conexão.',
            'No pudimos confirmar el guardado. Conservamos el formulario; reintentá con conexión.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !accessAllowed
      ? Scaffold(
          appBar: organizationAppBar('Agenda Premium'),
          body: Center(
              child: Text(t('A Agenda é uma função do MedCases Premium.',
                  'La Agenda es una función de MedCases Premium.'))))
      : Scaffold(
          appBar: organizationAppBar(widget.event == null
              ? t('Novo compromisso', 'Nuevo compromiso')
              : t('Editar compromisso', 'Editar compromiso')),
          body: SingleChildScrollView(
              key: const ValueKey('agenda-editor-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    organizationSection(context, t('Detalhes', 'Detalles'), [
                      TextField(
                          onTapOutside: (_) => dismissOrganizationKeyboard(),
                          controller: title,
                          maxLength: 160,
                          decoration: organizationInput(
                              context, t('Título', 'Título'))),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(
                              AgendaEvent.categories.length,
                              (i) => ChoiceChip(
                                  label: Text((widget.isEs
                                      ? [
                                          'Guardia',
                                          'Estudio',
                                          'Clase',
                                          'Consulta',
                                          'Personal',
                                          'Otro'
                                        ]
                                      : [
                                          'Plantão',
                                          'Estudo',
                                          'Aula',
                                          'Consulta',
                                          'Pessoal',
                                          'Outro'
                                        ])[i]),
                                  selected:
                                      category == AgendaEvent.categories[i],
                                  onSelected: (_) {
                                    dismissOrganizationKeyboard();
                                    setState(() =>
                                        category = AgendaEvent.categories[i]);
                                  }))),
                    ]),
                    organizationSection(context, t('Quando', 'Cuándo'), [
                      ListTile(
                          leading: const Icon(Icons.calendar_today_outlined),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          title: Text(t('Data', 'Fecha')),
                          subtitle: Text(
                              DateFormat.yMMMMd(widget.isEs ? 'es' : 'pt')
                                  .format(date)),
                          onTap: () async {
                            dismissOrganizationKeyboard();
                            final d = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100));
                            if (d != null) setState(() => date = d);
                          }),
                      ListTile(
                          leading: const Icon(Icons.schedule),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          title: Text(t('Hora de início', 'Hora de inicio')),
                          subtitle: Text(start.format(context)),
                          onTap: () async {
                            dismissOrganizationKeyboard();
                            final time = await showTimePicker(
                                context: context, initialTime: start);
                            if (time != null) setState(() => start = time);
                          }),
                      ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(t('Hora de fim (opcional)',
                              'Hora de fin (opcional)')),
                          subtitle: Text(end?.format(context) ?? '—'),
                          trailing: end == null
                              ? null
                              : IconButton(
                                  tooltip:
                                      t('Remover horário', 'Quitar horario'),
                                  onPressed: () => setState(() => end = null),
                                  icon: const Icon(Icons.close)),
                          onTap: () async {
                            dismissOrganizationKeyboard();
                            final time = await showTimePicker(
                                context: context, initialTime: end ?? start);
                            if (time != null) setState(() => end = time);
                          }),
                      if (end != null)
                        SwitchListTile(
                            title: Text(t('Termina no dia seguinte',
                                'Termina al día siguiente')),
                            value: overnight,
                            onChanged: (v) => setState(() => overnight = v)),
                    ]),
                    organizationSection(
                        context, t('Lembretes', 'Recordatorios'), [
                      DropdownButtonFormField<int>(
                          onTap: dismissOrganizationKeyboard,
                          initialValue: reminder ?? -1,
                          decoration: organizationInput(
                              context, t('Lembrete', 'Recordatorio')),
                          items: [
                            DropdownMenuItem(
                                value: -1,
                                child: Text(
                                    t('Sem lembrete', 'Sin recordatorio'))),
                            ...AgendaEvent.reminders.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m == 0
                                    ? t('No horário', 'En el horario')
                                    : m == 1440
                                        ? t('1 dia antes', '1 día antes')
                                        : m == 60
                                            ? t('1 hora antes', '1 hora antes')
                                            : '$m min ${t('antes', 'antes')}')))
                          ],
                          onChanged: (v) =>
                              setState(() => reminder = v == -1 ? null : v)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          onTap: dismissOrganizationKeyboard,
                          initialValue: recurrence,
                          decoration: organizationInput(
                              context, t('Repetição', 'Repetición')),
                          items: List.generate(
                              4,
                              (i) => DropdownMenuItem(
                                  value: AgendaEvent.recurrences[i],
                                  child: Text((widget.isEs
                                      ? [
                                          'No repetir',
                                          'Diaria',
                                          'Semanal',
                                          'Mensual'
                                        ]
                                      : [
                                          'Não repetir',
                                          'Diária',
                                          'Semanal',
                                          'Mensal'
                                        ])[i]))),
                          onChanged: (v) => setState(() => recurrence = v!)),
                    ]),
                    organizationSection(context, t('Notas', 'Notas'), [
                      TextField(
                          onTapOutside: (_) => dismissOrganizationKeyboard(),
                          controller: notes,
                          maxLength: 5000,
                          minLines: 3,
                          maxLines: 6,
                          decoration: organizationInput(context,
                              t('Notas opcionais', 'Notas opcionales'))),
                    ]),
                    organizationSection(
                        context, t('Calendário', 'Calendario'), [
                      SwitchListTile(
                          title: Text(t(
                              'Adicionar também ao calendário do dispositivo',
                              'Agregar también al calendario del dispositivo')),
                          value: calendarLinked,
                          onChanged: busy
                              ? null
                              : (value) =>
                                  setState(() => calendarLinked = value)),
                    ]),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: busy ? null : _save,
                        child: Text(busy
                            ? t('Salvando…', 'Guardando…')
                            : t('Salvar', 'Guardar'))),
                    if (widget.event != null)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                              title: Text(t(
                                                  'Excluir compromisso?',
                                                  '¿Eliminar compromiso?')),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: Text(t('Cancelar',
                                                        'Cancelar'))),
                                                FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: Text(t(
                                                        'Excluir', 'Eliminar')))
                                              ]));
                                  if (confirm != true || !context.mounted) {
                                    return;
                                  }
                                  setState(() => busy = true);
                                  try {
                                    if (!context.mounted) return;
                                    widget.repository.assertOwner(widget.owner);
                                    if (widget.event!.deviceCalendarLinked) {
                                      final removeNative = await showDialog<
                                              bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                                  title: Text(t(
                                                      'Excluir também do calendário do dispositivo?',
                                                      '¿Eliminar también del calendario del dispositivo?')),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, false),
                                                        child: Text(t(
                                                            'Manter no calendário',
                                                            'Mantener en calendario'))),
                                                    FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, true),
                                                        child: Text(t(
                                                            'Excluir também',
                                                            'Eliminar también')))
                                                  ]));
                                      if (removeNative == true) {
                                        await OrganizationDeviceCalendar()
                                            .delete(widget.event!);
                                      }
                                    }
                                    await widget.repository
                                        .delete(widget.event!)
                                        .timeout(const Duration(seconds: 15));
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() => error = t(
                                          'Não foi possível excluir. Tente novamente.',
                                          'No pudimos eliminar. Reintentá.'));
                                    }
                                  } finally {
                                    if (mounted) setState(() => busy = false);
                                  }
                                },
                          child: Text(t('Excluir', 'Eliminar'))),
                  ])));
}
