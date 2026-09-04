// notification_service.dart — MedCases Pro
// Notificações locais de alta precisão (mobile) + in-app overlay (web + mobile).
//
// ┌──────────────────────────────────────────────────────────┐
// │  Mobile  →  flutter_local_notifications                  │
// │             Android: AlarmManager exactAllowWhileIdle    │
// │             iOS:     UNTimeIntervalNotificationTrigger   │
// │  Web     →  in-app overlay apenas (sem push nativo)      │
// └──────────────────────────────────────────────────────────┘
//
// Canais:
//   medcases_shift   — Timer rápido de plantão   (IDs 1000+)
//   medcases_cockpit — Lembrete do cockpit        (IDs 2000+)
//   medcases_notes   — Alertas de anotações       (IDs 3000+)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

// flutter_local_notifications: mobile only, stub no Web
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'notification_web_stub.dart';

// timezone: necessário para zonedSchedule
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Tipos públicos
// ─────────────────────────────────────────────────────────────────────────────

/// Payload parseado ao tocar numa notificação.
/// Formato: 'shift_timer' | 'cockpit:reminder' | 'note:<noteId>'
class NotifPayload {
  final String raw;
  const NotifPayload(this.raw);

  String get type {
    if (raw.startsWith('note:'))    return 'note';
    if (raw.startsWith('cockpit:')) return 'cockpit';
    return raw;
  }

  String get id {
    final i = raw.indexOf(':');
    return i >= 0 ? raw.substring(i + 1) : '';
  }
}

typedef InAppAlertCb = void Function({
  required String title,
  required String body,
  required String payload,
  VoidCallback? onStop,
  Future<void> Function(int minutes)? onSnooze,
});

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static void Function(NotifPayload)? _onTap;
  static InAppAlertCb? _inAppAlert;
  static final Map<int, Timer>        _inAppTimers = {};
  // Callbacks de "parar" por ID — registados pelos widgets proprietários do timer
  static final Map<int, VoidCallback> _stopCallbacks = {};
  static final Map<int, Future<void> Function(int minutes)>
      _snoozeCallbacks =
      <int, Future<void> Function(int minutes)>{};
  static int _idCounter = 1000;

  static const _chShift   = 'medcases_shift';
  static const _chCockpit = 'medcases_cockpit';
  static const _chNotes   = 'medcases_notes';

  // ── Registro de callbacks ─────────────────────────────────────────────────

  static void setOnTap(void Function(NotifPayload) cb) => _onTap     = cb;
  static void setInAppAlert(InAppAlertCb cb)            => _inAppAlert = cb;

  /// Registra um callback chamado quando o usuário toca "Parar" no pop-up.
  /// O widget que agendou o timer (ex.: _ShiftTimerBarState) deve registrar
  /// aqui o seu método de cancelamento para que a UI pare imediatamente.
  static void registerStopCallback(int id, VoidCallback cb) =>
      _stopCallbacks[id] = cb;

  /// Retira atomicamente o callback proprietário antes de executá-lo.
  ///
  /// Isso impede que [cancel] remova o callback antes do fluxo "Parar"
  /// conseguir notificar o proprietário visual do timer.
  static VoidCallback? _takeStopCallback(int id) =>
      _stopCallbacks.remove(id);


  static void registerSnoozeCallback(
    int id,
    Future<void> Function(int minutes) callback,
  ) {
    if (id > 0) _snoozeCallbacks[id] = callback;
  }

  static Future<void> Function(int minutes)? _takeSnoozeCallback(int id) =>
      _snoozeCallbacks.remove(id);
  // ── Inicialização ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;

    if (kIsWeb) return; // Web só usa in-app overlay

    // Timezone
    try {
      tz_data.initializeTimeZones();
      final name = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      debugPrint('[Notif] timezone init: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse:           _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponse,
    );

    await _createChannels();
    debugPrint('[Notif] Pronto');
  }

  // ── Permissão ─────────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        // O projeto não possui entitlement de Critical Alerts.
        // Solicita somente permissões comuns de alerta, badge e som.
        final granted = await ios.requestPermissions(
              alert: true, badge: true, sound: true,
            ) ?? false;
        debugPrint('[Notif] iOS permissions granted=$granted');
        return granted;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('[Notif] requestPermission: $e');
    }
    return false;
  }

  // ── Agendar ───────────────────────────────────────────────────────────────

  /// Agenda notificação local daqui a [seconds] segundos.
  /// Retorna o ID (use para cancelar).
  static Future<int> scheduleTimer({
    required int    seconds,
    required String title,
    required String body,
    String  payload = 'shift_timer',
    String  channel = _chShift,
  }) async {
    if (!_ready) await init();
    final id = _idCounter++;

    // In-app overlay: funciona mesmo com app em foreground ou no Web
    _armInApp(id: id, seconds: seconds, title: title, body: body, payload: payload);

    if (kIsWeb) return id; // Web só usa in-app

    // BUILD 331/QA: padrão de vibração agressivo (3 pulsos longos) — estilo
    // banco/WhatsApp para não passar despercebido no bolso do médico.
    // [delay, on, off, on, off, on]  (ms)
    final vib = Int64List.fromList([0, 600, 200, 600, 200, 800]);
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    final isShiftTimer = channel == _chShift;

    final android = AndroidNotificationDetails(
      channel, _chLabel(channel),
      channelDescription: _chDesc(channel),
      importance:         Importance.max,
      priority:           Priority.high,
      playSound:          true,
      enableVibration:    true,
      vibrationPattern:   vib,
      category:           AndroidNotificationCategory.alarm,
      visibility:         isShiftTimer
          ? NotificationVisibility.public
          : NotificationVisibility.private,
      // Notificação estilo banco: heads-up e lock screen, sem abrir uma tela
      // invasiva. Full-screen intents são reservados a apps de chamadas/alarmes.
      fullScreenIntent:   isShiftTimer ? false : true,
      autoCancel:         false,  // persiste até o médico tocar (não some sozinho)
      ongoing:            false,
      styleInformation:   BigTextStyleInformation(body),
      ticker:             title,
    );

    // iOS utiliza somente níveis suportados sem entitlement adicional:
    //   1ª tentativa → InterruptionLevel.timeSensitive
    //   2ª tentativa → InterruptionLevel.active
    //
    // Android:
    //   Timer de Plantão tenta exactAllowWhileIdle primeiro.
    //   Como o manifesto remove permissões de exact alarm, faz fallback explícito
    //   para inexactAllowWhileIdle em vez de perder a notificação silenciosamente.
    final scheduleModes = isShiftTimer
        ? const [
            AndroidScheduleMode.exactAllowWhileIdle,
            AndroidScheduleMode.inexactAllowWhileIdle,
          ]
        : const [
            AndroidScheduleMode.exactAllowWhileIdle,
          ];

    bool _scheduled = false;
    for (final scheduleMode in scheduleModes) {
      for (final level in [
        InterruptionLevel.timeSensitive,
        InterruptionLevel.active,
      ]) {
        try {
          final darwin = DarwinNotificationDetails(
            sound:             'default',
            presentAlert:      true,
            presentBadge:      true,
            presentSound:      true,
            interruptionLevel: level,
          );
          await _plugin.zonedSchedule(
            id, title, body, when,
            NotificationDetails(android: android, iOS: darwin),
            payload:                                    payload,
            androidScheduleMode:                        scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint(
            '[Notif] Agendado id=$id ${seconds}s "$title" '
            'level=$level mode=$scheduleMode',
          );
          _scheduled = true;
          break;
        } catch (e) {
          debugPrint(
            '[Notif] scheduleTimer level=$level mode=$scheduleMode '
            'falhou: $e — tentando fallback',
          );
        }
      }
      if (_scheduled) break;
    }

    if (!_scheduled) {
      debugPrint('[Notif] scheduleTimer: todos os modos falharam para id=$id');
      return isShiftTimer ? -1 : id;
    }
    return id;
  }

  /// Lembrete do cockpit (reavaliação).
  static Future<int> scheduleCockpit({
    required int    minutes,
    required String lang,
  }) {
    final body = lang == 'es'
        ? '⏰ Tiempo de reevaluación agotado ($minutes min)'
        : '⏰ Tempo de reavaliação esgotado ($minutes min)';
    return scheduleTimer(
      seconds: minutes * 60,
      title:   'MedCases Pro',
      body:    body,
      payload: 'cockpit:reminder',
      channel: _chCockpit,
    );
  }

  /// Alerta de anotação.
  static Future<int> scheduleNote({
    required String noteId,
    required String noteTitle,
    required int    seconds,
    required String lang,
  }) {
    final title = lang == 'es' ? 'Recordatorio de anotación' : 'Lembrete de anotação';
    final body  = noteTitle.isNotEmpty ? noteTitle
        : (lang == 'es' ? 'Toca para ver tu anotación' : 'Toque para ver sua anotação');
    return scheduleTimer(
      seconds: seconds,
      title:   title,
      body:    body,
      payload: 'note:$noteId',
      channel: _chNotes,
    );
  }

  /// Alias para compatibilidade — usa scheduleNote internamente.
  static Future<int> scheduleNoteAlert({
    required String noteId,
    required String noteTitle,
    required int    seconds,
    required String lang,
  }) => scheduleNote(noteId: noteId, noteTitle: noteTitle, seconds: seconds, lang: lang);

  /// Alias: scheduleCockpit → scheduleCockpitReminder
  static Future<int> scheduleCockpitReminder({
    required int    minutes,
    required String lang,
  }) => scheduleCockpit(minutes: minutes, lang: lang);

  // ── Cancelar ──────────────────────────────────────────────────────────────

  static Future<void> cancel(int id) async {
    _inAppTimers[id]?.cancel();
    _inAppTimers.remove(id);
    _takeStopCallback(id);
    _takeSnoozeCallback(id);
    if (kIsWeb || id < 0) return;
    try { await _plugin.cancel(id); } catch (_) {}
    debugPrint('[Notif] Cancelado id=$id');
  }

  static Future<void> cancelAll() async {
    for (final t in _inAppTimers.values) { t.cancel(); }
    _inAppTimers.clear();
    _stopCallbacks.clear();
    _snoozeCallbacks.clear();
    if (kIsWeb) return;
    try { await _plugin.cancelAll(); } catch (_) {}
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  static void _armInApp({
    required int    id,
    required int    seconds,
    required String title,
    required String body,
    required String payload,
  }) {
    _inAppTimers[id]?.cancel();
    _inAppTimers[id] = Timer(Duration(seconds: seconds), () {
      _inAppTimers.remove(id);
      // onStop: cancela o agendamento E chama o widget proprietário (ex.: _ShiftTimerBar)
      final snoozeCallback = _snoozeCallbacks[id];
      _inAppAlert?.call(
        title: title,
        body:    body,
        payload: payload,
        onSnooze: snoozeCallback == null
            ? null
            : (minutes) async {
                final callback = _takeSnoozeCallback(id);
                try {
                  await callback?.call(minutes.clamp(1, 10));
                } finally {
                  await cancel(id);
                }
              },
        onStop: () {
          final ownerCallback = _takeStopCallback(id);

          try {
            ownerCallback?.call();
          } catch (error, stackTrace) {
            debugPrint(
              '[Notif] stop callback id=$id falhou: $error\n$stackTrace',
            );
          } finally {
            unawaited(cancel(id));
          }
        },
      );
    });
  }

  @pragma('vm:entry-point')
  static void _onResponse(NotificationResponse r) {
    final p = r.payload ?? '';
    debugPrint('[Notif] Tap payload=$p');
    if (p.isNotEmpty) _onTap?.call(NotifPayload(p));
  }

  static Future<void> _createChannels() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    // BUILD 331: vibrationPattern agressivo no canal Android — reproduz o
    // mesmo padrão de 3 pulsos longos mesmo que a notificação individual
    // não especifique o padrão (canal sobrescreve).
    final vib = Int64List.fromList([0, 600, 200, 600, 200, 800]);
    for (final ch in [_chShift, _chCockpit, _chNotes]) {
      await impl.createNotificationChannel(AndroidNotificationChannel(
        ch, _chLabel(ch),
        description:      _chDesc(ch),
        importance:       Importance.max,
        playSound:        true,
        enableVibration:  true,
        vibrationPattern: vib,
        showBadge:        true,
      ));
    }
  }

  static String _chLabel(String ch) => switch (ch) {
    _chShift   => 'Timer de Plantão',
    _chCockpit => 'Lembrete de Reavaliação',
    _chNotes   => 'Alertas de Anotações',
    _          => 'MedCases Pro',
  };

  static String _chDesc(String ch) => switch (ch) {
    _chShift   => 'Notificações de timer rápido de plantão',
    _chCockpit => 'Lembretes de reavaliação do cockpit clínico',
    _chNotes   => 'Alertas agendados para anotações',
    _          => 'Notificações do MedCases Pro',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationOverlay — envolve o app e exibe pop-up modal in-app
// ─────────────────────────────────────────────────────────────────────────────

/// Wrapper raiz: registra o callback in-app e abre o diálogo quando dispara.
/// No Web (e foreground mobile) exibe um Dialog modal centralizado com
/// botão "Parar" (cancela o timer) e "Fechar" (apenas fecha o pop-up).
/// Não há auto-dismiss nem piscamento.
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  const NotificationOverlay({super.key, required this.child});

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _PendingInAppAlert {
  const _PendingInAppAlert({
    required this.title,
    required this.body,
    required this.payload,
    this.onStop,
    this.onSnooze,
  });

  final String title;
  final String body;
  final String payload;
  final VoidCallback? onStop;
  final Future<void> Function(int minutes)? onSnooze;
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with WidgetsBindingObserver {
  static const Duration _navigatorRetryDelay =
      Duration(milliseconds: 250);

  final List<_PendingInAppAlert> _pendingAlerts =
      <_PendingInAppAlert>[];

  bool _dialogOpen = false;
  bool _drainScheduled = false;
  int _navigatorRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NotificationService._inAppAlert = (({
      required String title,
      required String body,
      required String payload,
      VoidCallback? onStop,
      Future<void> Function(int minutes)? onSnooze,
    }) {
      if (!mounted) return;

      _pendingAlerts.add(
        _PendingInAppAlert(
          title: title,
          body: body,
          payload: payload,
          onStop: onStop,
          onSnooze: onSnooze,
        ),
      );

      debugPrint(
        '[Notif] Overlay in-app enfileirado '
        'payload=$payload pending=${_pendingAlerts.length}',
      );

      _scheduleDrain();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleDrain();
    }
  }

  NavigatorState? _findMountedNavigator() {
    NavigatorState? result;

    void visit(Element element) {
      if (result != null) return;

      if (element is StatefulElement &&
          element.state is NavigatorState) {
        final candidate = element.state as NavigatorState;

        if (candidate.mounted && candidate.overlay != null) {
          result = candidate;
          return;
        }
      }

      element.visitChildElements(visit);
    }

    final root = WidgetsBinding.instance.rootElement;

    if (root == null) return null;

    try {
      visit(root);
    } catch (error, stackTrace) {
      debugPrint(
        '[Notif] Busca do Navigator será repetida: $error\n$stackTrace',
      );
    }

    return result;
  }

  void _scheduleDrain([
    Duration delay = Duration.zero,
  ]) {
    if (!mounted || _drainScheduled) return;

    _drainScheduled = true;

    Future<void>.delayed(delay, () {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _drainScheduled = false;

        if (!mounted) return;

        _presentNextAlert();
      });
    });
  }

  Future<void> _presentNextAlert() async {
    if (!mounted || _dialogOpen || _pendingAlerts.isEmpty) {
      return;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;

    if (lifecycle != null &&
        lifecycle != AppLifecycleState.resumed) {
      debugPrint(
        '[Notif] Overlay in-app aguardando foreground '
        'pending=${_pendingAlerts.length}; alerta nativo preservado.',
      );
      return;
    }

    final navigator = Navigator.maybeOf(
          context,
          rootNavigator: true,
        ) ??
        _findMountedNavigator();

    final dialogContext = navigator?.overlay?.context;

    if (dialogContext == null) {
      _navigatorRetries += 1;

      debugPrint(
        '[Notif] Overlay in-app aguardando Navigator '
        'retry=$_navigatorRetries pending=${_pendingAlerts.length}; '
        'alerta nativo preservado.',
      );

      _scheduleDrain(_navigatorRetryDelay);
      return;
    }

    _navigatorRetries = 0;

    final alert = _pendingAlerts.removeAt(0);
    _dialogOpen = true;

    try {
      await showDialog<void>(
        context: dialogContext,
        useRootNavigator: false,
        barrierDismissible: alert.payload == 'shift_timer',
        builder: (_) => _NotifDialog(
          title: alert.title,
          body: alert.body,
          payload: alert.payload,
          onStop: alert.onStop,
          onSnooze: alert.onSnooze,
        ),
      );
    } catch (error, stackTrace) {
      _pendingAlerts.insert(0, alert);

      debugPrint(
        '[Notif] Overlay in-app será repetido após falha: '
        '$error\n$stackTrace',
      );

      await Future<void>.delayed(_navigatorRetryDelay);
    } finally {
      _dialogOpen = false;

      if (mounted && _pendingAlerts.isNotEmpty) {
        _scheduleDrain();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService._inAppAlert = null;
    _pendingAlerts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog modal de notificação
// ─────────────────────────────────────────────────────────────────────────────
class _NotifDialog extends StatefulWidget {
  const _NotifDialog({
    required this.title,
    required this.body,
    required this.payload,
    this.onStop,
    this.onSnooze,
  });

  final String title;
  final String body;
  final String payload;
  final VoidCallback? onStop;
  final Future<void> Function(int minutes)? onSnooze;

  @override
  State<_NotifDialog> createState() => _NotifDialogState();
}

class _NotifDialogState extends State<_NotifDialog> {
  int _snoozeMinutes = 5;
  bool _busy = false;

  bool get _isShiftTimer => widget.payload == 'shift_timer';

  bool get _isEs {
    final sample = '${widget.title} ${widget.body}'.toLowerCase();
    return sample.contains('hola doc') ||
        sample.contains('revisión') ||
        sample.contains('revisar el paciente') ||
        sample.contains('recordatorio');
  }

  String get _patientLabel {
    final value = widget.body.trim();
    if (value.isEmpty) return '';
    final normalized = value.toLowerCase();
    const generic = <String>[
      'é hora de revisar o paciente',
      'es hora de revisar el paciente',
      'es hora de revisar al paciente',
      'tempo de revisão esgotado',
      'tiempo de revisión agotado',
    ];
    if (generic.any(normalized.contains)) return '';
    return value;
  }

  String _channelForPayload() {
    if (widget.payload.startsWith('note:')) return NotificationService._chNotes;
    if (widget.payload.startsWith('cockpit:')) {
      return NotificationService._chCockpit;
    }
    return NotificationService._chShift;
  }

  Future<void> _snooze() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onSnooze != null) {
        await widget.onSnooze!(_snoozeMinutes);
      } else {
        final id = await NotificationService.scheduleTimer(
          seconds: _snoozeMinutes * 60,
          title: _isEs ? 'Hola Doc.' : 'Olá Doc.',
          body: _isEs
              ? 'Es hora de revisar el paciente.'
              : 'É hora de revisar o paciente.',
          payload: widget.payload,
          channel: _channelForPayload(),
        );
        if (id > 0 && widget.onStop != null) {
          NotificationService.registerStopCallback(id, widget.onStop!);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;
    final background =
        dark ? const Color(0xFF1A1D23) : Colors.white;
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFD7DEE7);
    final accent =
        dark ? const Color(0xFF61D2CB) : const Color(0xFF087F7B);
    final titleColor =
        dark ? const Color(0xFFF8FAFC) : const Color(0xFF17202A);
    final muted =
        dark ? const Color(0xFFB2C0D0) : const Color(0xFF5F6B78);
    final danger =
        dark ? const Color(0xFFF28B82) : const Color(0xFFB42318);
    final patient = _patientLabel;

    final eyebrow = _isShiftTimer
        ? (_isEs ? 'REVISIÓN CLÍNICA' : 'REVISÃO CLÍNICA')
        : (_isEs ? 'RECORDATORIO' : 'LEMBRETE');
    final heading = _isShiftTimer
        ? (_isEs
            ? 'Es hora de revisar al paciente'
            : 'Hora de revisar o paciente')
        : widget.title;

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 25,
                      color: accent,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            heading,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: _isEs ? 'Cerrar' : 'Fechar',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: muted,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (patient.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          patient,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _isEs
                        ? 'La revisión programada llegó a su horario.'
                        : 'A revisão programada chegou ao horário definido.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_isShiftTimer) ...[
                  const SizedBox(height: 17),
                  Divider(
                    height: 1,
                    thickness: 0.7,
                    color: border,
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _snoozeMinutes,
                            isExpanded: true,
                            dropdownColor: background,
                            iconEnabledColor: accent,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            items: [
                              for (var minute = 1;
                                  minute <= 10;
                                  minute++)
                                DropdownMenuItem<int>(
                                  value: minute,
                                  child: Text('$minute min'),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() {
                                        _snoozeMinutes = value;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _snooze,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.snooze_rounded,
                                    size: 19,
                                  ),
                            label: Text(
                              _isEs
                                  ? 'Posponer $_snoozeMinutes min'
                                  : 'Adiar $_snoozeMinutes min',
                            ),
                            style: ButtonStyle(
                              elevation:
                                  const WidgetStatePropertyAll(0),
                              backgroundColor:
                                  WidgetStatePropertyAll(accent),
                              foregroundColor:
                                  WidgetStatePropertyAll(
                                dark
                                    ? const Color(0xFF102320)
                                    : Colors.white,
                              ),
                              textStyle:
                                  const WidgetStatePropertyAll(
                                TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: border,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: titleColor,
                      ),
                      child: Text(
                        _isEs ? 'Cerrar' : 'Fechar',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.onStop != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                widget.onStop!();
                                Navigator.of(context).pop();
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: danger,
                        ),
                        child: Text(
                          _isEs
                              ? 'Finalizar timer'
                              : 'Encerrar timer',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
