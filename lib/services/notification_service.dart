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
  VoidCallback? onStop,   // callback opcional para "Parar" o timer agendado
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

  static void _unregisterStopCallback(int id) => _stopCallbacks.remove(id);

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
        // BUILD 331: solicita 'criticalAlert' além de alert/badge/sound.
        // CriticalAlert bypassa o modo Não Perturbe e o volume silencioso do
        // iPhone — essencial para alertas de revisão de paciente no plantão.
        // Requer entitlement 'com.apple.developer.usernotifications.critical-alerts'
        // no Xcode. Sem o entitlement a chamada é silenciosa (ignored by iOS).
        final granted = await ios.requestPermissions(
              alert: true, badge: true, sound: true,
              critical: true,                         // NEW: critical alert
            ) ?? false;
        debugPrint('[Notif] iOS permissions granted=$granted (critical requested)');
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

    final android = AndroidNotificationDetails(
      channel, _chLabel(channel),
      channelDescription: _chDesc(channel),
      importance:         Importance.max,
      priority:           Priority.high,
      playSound:          true,
      enableVibration:    true,
      vibrationPattern:   vib,
      category:           AndroidNotificationCategory.alarm,
      fullScreenIntent:   true,   // heads-up obrigatório mesmo com tela bloqueada
      autoCancel:         false,  // persiste até o médico tocar (não some sozinho)
      ongoing:            false,
      styleInformation:   BigTextStyleInformation(body),
      ticker:             title,
    );

    // BUILD 331: iOS critical bypassa Não Perturbe/volume mínimo.
    // BUILD 331/QA: Estratégia de downgrade em 3 níveis para garantir entrega
    // mesmo sem o entitlement 'com.apple.developer.usernotifications.critical-alerts':
    //   1ª tentativa → InterruptionLevel.critical  (bypassa DND — requer entitlement)
    //   2ª tentativa → InterruptionLevel.timeSensitive (heads-up sem DND bypass)
    //   3ª tentativa → InterruptionLevel.active (banner padrão — fallback máximo)
    // Isso evita que o médico perca o alerta por ausência do entitlement no Xcode.
    bool _scheduled = false;
    for (final level in [
      InterruptionLevel.critical,
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
          androidScheduleMode:                        AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('[Notif] Agendado id=$id ${seconds}s "$title" level=$level');
        _scheduled = true;
        break; // sucesso — não tenta próximo nível
      } catch (e) {
        debugPrint('[Notif] scheduleTimer level=$level falhou: $e — tentando downgrade');
        // continua loop para próximo nível
      }
    }
    if (!_scheduled) {
      debugPrint('[Notif] scheduleTimer: todos os níveis falharam para id=$id');
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
    _unregisterStopCallback(id);
    if (kIsWeb || id < 0) return;
    try { await _plugin.cancel(id); } catch (_) {}
    debugPrint('[Notif] Cancelado id=$id');
  }

  static Future<void> cancelAll() async {
    for (final t in _inAppTimers.values) { t.cancel(); }
    _inAppTimers.clear();
    _stopCallbacks.clear();
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
      _inAppAlert?.call(
        title:   title,
        body:    body,
        payload: payload,
        onStop:  () {
          cancel(id);
          _stopCallbacks[id]?.call();
          _unregisterStopCallback(id);
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

class _NotificationOverlayState extends State<NotificationOverlay> {
  // Evita abrir dois diálogos simultâneos para a mesma notificação
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    NotificationService.setInAppAlert(({
      required String title,
      required String body,
      required String payload,
      VoidCallback?  onStop,
    }) {
      if (!mounted || _dialogOpen) return;
      _dialogOpen = true;
      showDialog<void>(
        context:     context,
        barrierDismissible: false, // só fecha pelos botões
        builder:     (_) => _NotifDialog(
          title:   title,
          body:    body,
          payload: payload,
          onStop:  onStop,
        ),
      ).then((_) => _dialogOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog modal de notificação
// ─────────────────────────────────────────────────────────────────────────────
class _NotifDialog extends StatelessWidget {
  final String title;
  final String body;
  final String payload;
  final VoidCallback? onStop;

  const _NotifDialog({
    required this.title,
    required this.body,
    required this.payload,
    this.onStop,
  });

  // Ícone por tipo de payload
  IconData get _icon {
    if (payload.startsWith('note:'))    return Icons.note_rounded;
    if (payload.startsWith('cockpit:')) return Icons.monitor_heart_rounded;
    return Icons.alarm_rounded; // shift_timer
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final cardBg    = dark ? const Color(0xFF18281E) : Colors.white;
    final accentGrn = const Color(0xFF1F6B48);
    final liveGrn   = const Color(0xFF4ADE80);
    final titleC    = dark ? Colors.white : const Color(0xFF0D2218);
    final bodyC     = dark
        ? Colors.white.withOpacity(0.72)
        : const Color(0xFF334155);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: cardBg,
          border: Border.all(
            color: accentGrn.withOpacity(dark ? 0.50 : 0.20), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.55 : 0.14),
              blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Ícone ────────────────────────────────────────────────────────
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGrn.withOpacity(dark ? 0.22 : 0.10),
              ),
              child: Icon(_icon, color: liveGrn, size: 30),
            ),
            const SizedBox(height: 18),

            // ── Título ───────────────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900,
                color: titleC, letterSpacing: -0.3, height: 1.2),
            ),

            // ── Corpo ────────────────────────────────────────────────────────
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5, height: 1.45, color: bodyC),
              ),
            ],

            const SizedBox(height: 26),

            // ── Botões ───────────────────────────────────────────────────────
            Row(children: [

              // Botão "Fechar" — apenas fecha o diálogo, timer segue agendado
              Expanded(
                child: _DialogBtn(
                  label:   'Fechar',
                  icon:    Icons.close_rounded,
                  filled:  false,
                  dark:    dark,
                  onTap:   () => Navigator.of(context).pop(),
                ),
              ),

              // Só mostra "Parar" se onStop foi fornecido (shift_timer / cockpit)
              if (onStop != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogBtn(
                    label:  'Parar',
                    icon:   Icons.stop_circle_rounded,
                    filled: true,
                    dark:   dark,
                    onTap:  () {
                      onStop!();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão reutilizável do diálogo
// ─────────────────────────────────────────────────────────────────────────────
class _DialogBtn extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final bool      filled;
  final bool      dark;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentGrn = const Color(0xFF1F6B48);
    final bg = filled
        ? accentGrn
        : (dark
            ? Colors.white.withOpacity(0.07)
            : const Color(0xFFF1F5F9));
    final fgColor = filled
        ? Colors.white
        : (dark ? Colors.white70 : const Color(0xFF475569));
    final borderColor = filled
        ? Colors.transparent
        : (dark
            ? Colors.white.withOpacity(0.12)
            : const Color(0xFFCBD5E1));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bg,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700,
              color: fgColor, letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}
