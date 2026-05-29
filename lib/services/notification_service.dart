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
  static final Map<int, Timer> _inAppTimers = {};
  static int _idCounter = 1000;

  static const _chShift   = 'medcases_shift';
  static const _chCockpit = 'medcases_cockpit';
  static const _chNotes   = 'medcases_notes';

  // ── Registro de callbacks ─────────────────────────────────────────────────

  static void setOnTap(void Function(NotifPayload) cb)  => _onTap     = cb;
  static void setInAppAlert(InAppAlertCb cb)             => _inAppAlert = cb;

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
        return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
            false;
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

    try {
      final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

      final vib = Int64List.fromList([0, 400, 200, 400]);

      final android = AndroidNotificationDetails(
        channel, _chLabel(channel),
        channelDescription: _chDesc(channel),
        importance:         Importance.max,
        priority:           Priority.high,
        playSound:          true,
        enableVibration:    true,
        vibrationPattern:   vib,
        category:           AndroidNotificationCategory.alarm,
        fullScreenIntent:   true,
        autoCancel:         true,
        styleInformation:   BigTextStyleInformation(body),
      );
      const darwin = DarwinNotificationDetails(
        sound:             'default',
        presentAlert:      true,
        presentBadge:      true,
        presentSound:      true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      await _plugin.zonedSchedule(
        id, title, body, when,
        NotificationDetails(android: android, iOS: darwin),
        payload:                                    payload,
        androidScheduleMode:                        AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('[Notif] Agendado id=$id ${seconds}s "$title"');
    } catch (e) {
      debugPrint('[Notif] scheduleTimer error: $e');
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
    if (kIsWeb || id < 0) return;
    try { await _plugin.cancel(id); } catch (_) {}
    debugPrint('[Notif] Cancelado id=$id');
  }

  static Future<void> cancelAll() async {
    for (final t in _inAppTimers.values) { t.cancel(); }
    _inAppTimers.clear();
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
      _inAppAlert?.call(title: title, body: body, payload: payload);
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
    for (final ch in [_chShift, _chCockpit, _chNotes]) {
      await impl.createNotificationChannel(AndroidNotificationChannel(
        ch, _chLabel(ch),
        description:    _chDesc(ch),
        importance:     Importance.max,
        playSound:      true,
        enableVibration: true,
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
// NotificationOverlay — envolve o app e exibe banners in-app
// ─────────────────────────────────────────────────────────────────────────────

class NotificationOverlay extends StatefulWidget {
  final Widget child;
  const NotificationOverlay({super.key, required this.child});

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final List<_BannerEntry> _queue = [];

  @override
  void initState() {
    super.initState();
    NotificationService.setInAppAlert(({
      required String title,
      required String body,
      required String payload,
    }) {
      if (!mounted) return;
      setState(() {
        final entry = _BannerEntry(
          key:     ValueKey('b_${DateTime.now().microsecondsSinceEpoch}'),
          title:   title,
          body:    body,
          payload: payload,
        );
        _queue.add(entry);
        if (_queue.length > 3) _queue.removeAt(0); // máx 3 sobrepostos
      });
    });
  }

  void _dismiss(_BannerEntry e) {
    if (mounted) setState(() => _queue.remove(e));
  }

  void _tapBanner(String payload) {
    if (mounted) setState(() => _queue.clear());
    NotificationService._onTap?.call(NotifPayload(payload));
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned(
        top:   MediaQuery.of(context).padding.top + 8,
        left:  12,
        right: 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _queue.map((e) => _InAppBannerWidget(
            key:       e.key,
            title:     e.title,
            body:      e.body,
            payload:   e.payload,
            onDismiss: () => _dismiss(e),
            onTap:     _tapBanner,
          )).toList(),
        ),
      ),
    ]);
  }
}

class _BannerEntry {
  final Key    key;
  final String title;
  final String body;
  final String payload;
  _BannerEntry({required this.key, required this.title, required this.body, required this.payload});
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner animado individual
// ─────────────────────────────────────────────────────────────────────────────
class _InAppBannerWidget extends StatefulWidget {
  final String title, body, payload;
  final VoidCallback        onDismiss;
  final void Function(String) onTap;

  const _InAppBannerWidget({
    super.key,
    required this.title,
    required this.body,
    required this.payload,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InAppBannerWidget> createState() => _InAppBannerWidgetState();
}

class _InAppBannerWidgetState extends State<_InAppBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _auto = Timer(const Duration(seconds: 6), _dismiss);
  }

  @override
  void dispose() { _auto?.cancel(); _ctrl.dispose(); super.dispose(); }

  Future<void> _dismiss() async {
    _auto?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: () => widget.onTap(widget.payload),
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: dark ? const Color(0xFF18281E) : const Color(0xFF0D2218),
                  border: Border.all(
                    color: const Color(0xFF1F6B48).withValues(alpha: 0.55), width: 1.2),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 18, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1F6B48).withValues(alpha: 0.20),
                    ),
                    child: const Icon(Icons.alarm_rounded,
                      color: Color(0xFF4ADE80), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.2)),
                      if (widget.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(widget.body, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.3,
                            color: Colors.white.withValues(alpha: 0.72))),
                      ],
                    ],
                  )),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, size: 16,
                        color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
