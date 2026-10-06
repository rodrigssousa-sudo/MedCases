import 'organization_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/organization/organization_timer.dart';
import '../../services/organization/organization_timer_runtime.dart';
import '../../services/organization/organization_notifications.dart';

Future<void> organizationPermission(BuildContext context,
    MedCasesOrganizationNotifications alerts, bool isEs) async {
  OrganizationPermission status;
  try {
    status = await alerts.getPermissionStatus();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEs
              ? 'No pudimos verificar el permiso de notificaciones. Inténtalo nuevamente.'
              : 'Não foi possível verificar a permissão de notificações. Tente novamente.')));
    }
    return;
  }
  if (!context.mounted || status == OrganizationPermission.granted) return;
  if (status == OrganizationPermission.unknown) {
    final request = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(isEs ? 'Notificaciones' : 'Notificações'),
                content: Text(isEs
                    ? 'Activá las notificaciones para recibir avisos incluso cuando MedCases esté en segundo plano o la pantalla esté bloqueada.'
                    : 'Ative as notificações para receber avisos mesmo com o MedCases em segundo plano ou com a tela bloqueada.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isEs ? 'Ahora no' : 'Agora não')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(isEs ? 'Activar' : 'Ativar'))
                ]));
    if (request == true) await alerts.requestPermission();
  } else {
    final settings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(isEs
                    ? 'Notificaciones desactivadas'
                    : 'Notificações desativadas'),
                content: Text(isEs
                    ? 'Activá los avisos en la configuración del dispositivo.'
                    : 'Ative os avisos nas configurações do dispositivo.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isEs ? 'Cerrar' : 'Fechar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(isEs
                          ? 'Activar notificaciones'
                          : 'Ativar notificações'))
                ]));
    if (settings == true) await alerts.openSystemSettings();
  }
}

class OrganizationTimerScreen extends StatefulWidget {
  const OrganizationTimerScreen({super.key, required this.isEs});
  final bool isEs;
  @override
  State<OrganizationTimerScreen> createState() =>
      _OrganizationTimerScreenState();
}

class _OrganizationTimerScreenState extends State<OrganizationTimerScreen>
    with WidgetsBindingObserver {
  late final MedCasesOrganizationNotifications alerts;
  late final OrganizationTimerController controller;
  Timer? ticker;
  OrganizationPermission? permission;
  int permissionRead = 0;
  int seconds = 25 * 60;
  bool custom = false;
  final hours = TextEditingController(text: '0');
  final minutes = TextEditingController(text: '25');
  final customSeconds = TextEditingController(text: '0');
  String t(String pt, String es) => widget.isEs ? es : pt;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    alerts = MedCasesOrganizationNotifications(isEs: widget.isEs);
    controller = OrganizationTimerRuntime.get(isEs: widget.isEs);
    controller.addListener(_repaint);
    unawaited(_action(controller.restore));
    unawaited(_refreshPermission());
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = controller.state;
      if (state?.status == OrganizationTimerStatus.running &&
          state!.remaining(DateTime.now()) == 0) {
        unawaited(_action(controller.reconcile));
      } else {
        setState(() {});
      }
    });
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_action(controller.reconcile));
      unawaited(_refreshPermission());
    }
  }

  Future<void> _refreshPermission() async {
    final generation = ++permissionRead;
    try {
      final next = await alerts.getPermissionStatus();
      if (mounted && generation == permissionRead) {
        setState(() => permission = next);
      }
    } catch (_) {
      if (mounted && generation == permissionRead) {
        setState(() => permission = null);
      }
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t(
                'Não foi possível atualizar o timer. Tente novamente.',
                'No pudimos actualizar el timer. Inténtalo nuevamente.'))));
      }
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_repaint);

    hours.dispose();
    minutes.dispose();
    customSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final status = state?.status ?? OrganizationTimerStatus.idle;
    final active = status == OrganizationTimerStatus.running ||
        status == OrganizationTimerStatus.paused;
    final remaining = state?.remaining(DateTime.now()) ?? seconds;
    final display = remaining >= 3600
        ? '${remaining ~/ 3600}:${(remaining ~/ 60 % 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}'
        : '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    return Scaffold(
        appBar: organizationAppBar('Timer'),
        body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        side: const WidgetStatePropertyAll(BorderSide.none),
                        backgroundColor:
                            const WidgetStatePropertyAll(Colors.transparent),
                        foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: .65)),
                        textStyle: WidgetStateProperty.resolveWith((states) =>
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight:
                                    states.contains(WidgetState.selected)
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                      ),
                      segments: [
                        const ButtonSegment(
                            value: false, label: Text('Pomodoro')),
                        ButtonSegment(
                            value: true,
                            label: Text(t('Personalizado', 'Personalizado')))
                      ],
                      selected: {custom},
                      onSelectionChanged: active
                          ? null
                          : (s) => setState(() => custom = s.single)),
                  const SizedBox(height: 24),
                  const SizedBox(height: 32),
                  Center(
                      child: SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 80)
                              .clamp(220.0, 320.0),
                          height: (MediaQuery.sizeOf(context).width - 80)
                              .clamp(220.0, 320.0),
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox.expand(
                                child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: .8),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    value: active
                                        ? remaining / state!.durationSeconds
                                        : status ==
                                                OrganizationTimerStatus.finished
                                            ? 0
                                            : 1)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: FittedBox(
                                      child: Text(display,
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayLarge
                                              ?.copyWith(
                                                  fontSize: 56,
                                                  fontWeight: FontWeight.w300,
                                                  letterSpacing: 1)))),
                              Text(
                                  switch (status) {
                                    OrganizationTimerStatus.running =>
                                      t('Em andamento', 'En curso'),
                                    OrganizationTimerStatus.paused =>
                                      t('Pausado', 'En pausa'),
                                    OrganizationTimerStatus.finished =>
                                      t('Finalizado', 'Finalizado'),
                                    _ => t('Pronto para começar',
                                        'Listo para empezar')
                                  },
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant))
                            ])
                          ]))),
                  const SizedBox(height: 32),
                  if (OrganizationTimerRuntime.nativeStatus != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(t(
                            'A exibição do timer na tela bloqueada não está disponível neste dispositivo. O timer continua no app.',
                            'La visualización del timer en la pantalla bloqueada no está disponible en este dispositivo. El timer continúa en la app.'))),
                  if (permission == OrganizationPermission.denied ||
                      permission == OrganizationPermission.systemDisabled)
                    TextButton.icon(
                        onPressed: () => alerts.openSystemSettings(),
                        icon: const Icon(Icons.notifications_off_outlined),
                        label: Text(t('Notificações desativadas · Ajustes',
                            'Notificaciones desactivadas · Ajustes'))),
                  if (!active)
                    TextButton.icon(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(160, 56),
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface),
                        icon: Icon(
                            !active || status == OrganizationTimerStatus.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 28),
                        onPressed: controller.busy
                            ? null
                            : () async {
                                dismissOrganizationKeyboard();
                                var duration = seconds;
                                if (custom) {
                                  final h = int.tryParse(hours.text),
                                      m = int.tryParse(minutes.text),
                                      s = int.tryParse(customSeconds.text);
                                  if (h == null ||
                                      m == null ||
                                      s == null ||
                                      h < 0 ||
                                      m < 0 ||
                                      m > 59 ||
                                      s < 0 ||
                                      s > 59) {
                                    await _action(() async {
                                      throw const FormatException();
                                    });
                                    return;
                                  }
                                  duration = h * 3600 + m * 60 + s;
                                }
                                if (duration <= 0) {
                                  await _action(() async {
                                    throw const FormatException();
                                  });
                                  return;
                                }
                                await organizationPermission(
                                    context, alerts, widget.isEs);
                                await _refreshPermission();
                                await _action(() => controller.start(duration));
                              },
                        label: Text(t('Iniciar', 'Iniciar'),
                            style: Theme.of(context).textTheme.titleLarge)),
                  if (active)
                    TextButton.icon(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(160, 56),
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface),
                        icon: Icon(
                            !active || status == OrganizationTimerStatus.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 28),
                        onPressed: controller.busy
                            ? null
                            : () => _action(
                                status == OrganizationTimerStatus.running
                                    ? controller.pause
                                    : controller.resume),
                        label: Text(status == OrganizationTimerStatus.running
                            ? t('Pausar', 'Pausar')
                            : t('Continuar', 'Continuar'))),
                  if (state != null)
                    Wrap(alignment: WrapAlignment.center, children: [
                      TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => _action(controller.reset),
                          child: Text(t('Reiniciar', 'Reiniciar'))),
                      TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => _action(controller.cancel),
                          child: Text(t('Cancelar', 'Cancelar')))
                    ]),
                  const SizedBox(height: 28),
                  if (!active && !custom)
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: [5, 10, 15, 25, 30, 60]
                                .map((m) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: TextButton(
                                          style: TextButton.styleFrom(
                                              foregroundColor: seconds == m * 60
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                              minimumSize: const Size(64, 64)),
                                          onPressed: () => setState(() {
                                                seconds = m * 60;
                                                if (state != null) {
                                                  unawaited(_action(
                                                      controller.cancel));
                                                }
                                              }),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('$m min'),
                                                const SizedBox(height: 10),
                                                Container(
                                                    height: 3,
                                                    width: 18,
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(2),
                                                        color: seconds ==
                                                                m * 60
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Colors
                                                                .transparent)),
                                              ])),
                                    ))
                                .toList())),
                  if (!active && custom)
                    Row(children: [
                      _number(hours, t('Horas', 'Horas')),
                      const SizedBox(width: 12),
                      _number(minutes, t('Minutos', 'Minutos')),
                      const SizedBox(width: 12),
                      _number(customSeconds, t('Segundos', 'Segundos'))
                    ]),
                ])));
  }

  Widget _number(TextEditingController controller, String label) => Expanded(
      child: TextField(
          onTapOutside: (_) => dismissOrganizationKeyboard(),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: organizationInput(context, label)));
}
