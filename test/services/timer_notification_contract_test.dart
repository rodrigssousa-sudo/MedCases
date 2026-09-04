import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _section(
  String source,
  String startMarker,
  String endMarker,
) {
  final start = source.indexOf(startMarker);
  if (start < 0) {
    throw StateError('Marcador inicial não encontrado: $startMarker');
  }

  final end = source.indexOf(endMarker, start + startMarker.length);
  if (end < 0) {
    throw StateError('Marcador final não encontrado: $endMarker');
  }

  return source.substring(start, end);
}

int _occurrences(String source, Pattern pattern) {
  if (pattern is RegExp) {
    return pattern.allMatches(source).length;
  }

  final value = pattern.toString();
  if (value.isEmpty) return 0;

  var count = 0;
  var offset = 0;

  while (true) {
    final index = source.indexOf(value, offset);
    if (index < 0) return count;

    count++;
    offset = index + value.length;
  }
}

void main() {
  late String home;
  late String service;
  late String shiftOwner;
  late String historialOwner;

  setUpAll(() {
    home = _read('lib/screens/home_screen.dart');
    service = _read('lib/services/notification_service.dart');

    shiftOwner = _section(
      home,
      'class _ShiftTimerBarState',
      'class _HistorialCompactCard',
    );

    historialOwner = _section(
      home,
      'class _HistorialCompactCardState',
      '// RECENTES',
    );
  });

  group('Micro Build 1 — caracterização do baseline atual', () {
    test('ShiftTimer é consumidor e Historial é proprietário único', () {
      expect(home, contains('class _ShiftTimerBarState'));
      expect(home, contains('class _HistorialCompactCardState'));

      expect(
        RegExp(r'Timer\.periodic\s*\(').hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(r'Timer\.periodic\s*\(').hasMatch(historialOwner),
        isTrue,
      );
      expect(
        shiftOwner,
        contains('ValueListenableBuilder<_TimerVisualState>'),
      );
    });

    test('ShiftTimer não mantém estado temporal próprio', () {
      expect(RegExp(r'bool\s+_active\s*=').hasMatch(shiftOwner), isFalse);
      expect(
        RegExp(r'int\s+_remainingSecs\s*=').hasMatch(shiftOwner),
        isFalse,
      );
      expect(RegExp(r'Timer\?\s+_ticker').hasMatch(shiftOwner), isFalse);

      expect(
        RegExp(r'int\s+_remainingSecs\s*=\s*0').hasMatch(historialOwner),
        isTrue,
      );
      expect(
        RegExp(r'Timer\?\s+_countdownTimer').hasMatch(historialOwner),
        isTrue,
      );
      expect(historialOwner, contains('bool get _timerActive'));
    });

    test('notification ID existe somente no proprietário canônico', () {
      expect(RegExp(r'int\s+_notifId').hasMatch(shiftOwner), isFalse);
      expect(
        RegExp(r'int\s+_notifId\s*=\s*0').hasMatch(historialOwner),
        isTrue,
      );
      expect(shiftOwner, isNot(contains('_kShiftNotifKey')));
      expect(historialOwner, contains('_kPomodoroNotifKey'));
    });

    test('SharedPreferences existe somente no proprietário canônico', () {
      expect(shiftOwner, isNot(contains('shift_timer_end_time')));
      expect(shiftOwner, isNot(contains('shift_timer_label')));
      expect(shiftOwner, isNot(contains('shift_timer_notif_id')));
      expect(
        RegExp(r'SharedPreferences\.getInstance\s*\(').hasMatch(shiftOwner),
        isFalse,
      );

      expect(historialOwner, contains('pomodoro_end_time'));
      expect(historialOwner, contains('pomodoro_label'));
      expect(historialOwner, contains('pomodoro_notif_id'));
      expect(
        RegExp(r'SharedPreferences\.getInstance\s*\(').hasMatch(historialOwner),
        isTrue,
      );
    });

    test('agendamento existe somente no proprietário canônico', () {
      expect(
        RegExp(r'NotificationService\.scheduleTimer\s*\(').hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(r'NotificationService\.scheduleTimer\s*\(')
            .hasMatch(historialOwner),
        isTrue,
      );
    });

    test('cálculo wall-clock existe somente no proprietário canônico', () {
      expect(
        RegExp(
          r'endTime\.difference\s*\(\s*DateTime\.now\s*\(\s*\)\s*\)',
        ).hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(
          r'endTime\.difference\s*\(\s*DateTime\.now\s*\(\s*\)\s*\)',
        ).hasMatch(historialOwner),
        isTrue,
      );
      expect(
        RegExp(r'DateTime\.now\s*\(\s*\)\.add\s*\(').hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(r'DateTime\.now\s*\(\s*\)\.add\s*\(').hasMatch(historialOwner),
        isTrue,
      );
    });

    test('restauração e foreground pertencem somente ao Historial', () {
      expect(shiftOwner, isNot(contains('_restoreTimerFromPrefs')));
      expect(historialOwner, contains('_restoreTimerFromPrefs();'));

      expect(
        RegExp(
          r'AppLifecycleState\.resumed[\s\S]*?_restoreTimerFromPrefs\s*\(\s*\)',
        ).hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(
          r'AppLifecycleState\.resumed[\s\S]*?_restoreTimerFromPrefs\s*\(\s*\)',
        ).hasMatch(historialOwner),
        isTrue,
      );
    });

    test('lifecycle pertence somente ao proprietário canônico', () {
      expect(
        RegExp(r'WidgetsBinding\.instance\.addObserver').hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(r'WidgetsBinding\.instance\.removeObserver')
            .hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(r'WidgetsBinding\.instance\.addObserver')
            .hasMatch(historialOwner),
        isTrue,
      );
      expect(
        RegExp(r'WidgetsBinding\.instance\.removeObserver')
            .hasMatch(historialOwner),
        isTrue,
      );
    });

    test('ShiftTimer não possui responsabilidades de proprietário', () {
      expect(shiftOwner, isNot(contains('NotificationService.')));
      expect(shiftOwner, isNot(contains('SharedPreferences')));
      expect(shiftOwner, isNot(contains('Timer.periodic')));
      expect(shiftOwner, isNot(contains('_ticker')));
      expect(shiftOwner, isNot(contains('_notifId')));
      expect(shiftOwner, isNot(contains('WidgetsBindingObserver')));
    });

    test('Historial preserva timer canônico durante dispose', () {
      final disposeStart = historialOwner.indexOf('void dispose()');
      final disposeEnd = historialOwner.indexOf('Widget build(', disposeStart);

      expect(disposeStart, greaterThanOrEqualTo(0));
      expect(disposeEnd, greaterThan(disposeStart));

      final disposeBlock = historialOwner.substring(disposeStart, disposeEnd);

      expect(
        disposeBlock,
        contains('_cancelTimer(updateUi: false)'),
      );
      expect(
        disposeBlock,
        isNot(contains('_countdownTimer?.cancel()')),
      );
      expect(
        disposeBlock,
        isNot(contains('_countdownTimer = null')),
      );
      expect(disposeBlock, contains('super.dispose()'));

      final cancelStart = historialOwner.indexOf('void _cancelTimer');
      final cancelEnd =
          historialOwner.indexOf('void _onTimerExpired', cancelStart);

      expect(cancelStart, greaterThanOrEqualTo(0));
      expect(cancelEnd, greaterThan(cancelStart));

      final cancelBlock = historialOwner.substring(cancelStart, cancelEnd);

      expect(
        cancelBlock,
        contains('_countdownTimer?.cancel()'),
      );
      expect(
        cancelBlock,
        contains('_countdownTimer = null'),
      );
      expect(
        cancelBlock,
        contains('NotificationService.cancel(_notifId)'),
      );
      expect(
        cancelBlock,
        contains('_clearTimerPrefs()'),
      );
    });

    test('Historial é o único proprietário do callback Parar', () {
      final canonicalCallback = RegExp(
        r'NotificationService\.registerStopCallback\s*\(\s*'
        r'(?:notifId|id)\s*,\s*_cancelTimer\s*,?\s*\)',
      );

      expect(
        canonicalCallback.hasMatch(historialOwner),
        isTrue,
      );
      expect(
        canonicalCallback.hasMatch(shiftOwner),
        isFalse,
      );
      expect(
        RegExp(
          r'NotificationService\.registerStopCallback\s*\(',
        ).hasMatch(shiftOwner),
        isFalse,
      );
    });

    test('callback Parar preserva o proprietário antes do cancelamento', () {
      final armStart = service.indexOf('static void _armInApp');
      expect(armStart, greaterThanOrEqualTo(0));

      final takeIndex = service.indexOf(
          'final ownerCallback = _takeStopCallback(id)', armStart);
      final callbackIndex = service.indexOf('ownerCallback?.call()', armStart);
      final cancelIndex = service.indexOf('unawaited(cancel(id))', armStart);

      expect(takeIndex, greaterThan(armStart));
      expect(callbackIndex, greaterThan(takeIndex));
      expect(cancelIndex, greaterThan(callbackIndex));
    });

    test('registra que cancel remove timer e callback', () {
      final cancelStart = service.indexOf('static Future<void> cancel(int id)');
      final cancelEnd =
          service.indexOf('static Future<void> cancelAll()', cancelStart);

      expect(cancelStart, greaterThanOrEqualTo(0));
      expect(cancelEnd, greaterThan(cancelStart));

      final cancelBlock = service.substring(cancelStart, cancelEnd);

      expect(cancelBlock, contains('_inAppTimers[id]?.cancel()'));
      expect(cancelBlock, contains('_inAppTimers.remove(id)'));
      expect(cancelBlock, contains('_takeStopCallback(id)'));
      expect(cancelBlock, contains('_plugin.cancel(id)'));
    });

    test('registra limpeza global de timers e callbacks', () {
      final cancelAllStart = service.indexOf('static Future<void> cancelAll()');
      final cancelAllEnd = service.indexOf('// ── Internos', cancelAllStart);

      expect(cancelAllStart, greaterThanOrEqualTo(0));
      expect(cancelAllEnd, greaterThan(cancelAllStart));

      final cancelAllBlock = service.substring(cancelAllStart, cancelAllEnd);

      expect(cancelAllBlock, contains('_inAppTimers.clear()'));
      expect(cancelAllBlock, contains('_stopCallbacks.clear()'));
      expect(cancelAllBlock, contains('_plugin.cancelAll()'));
    });

    test('registra timer in-app do NotificationService', () {
      expect(
        RegExp(
          r'_inAppTimers\[id\]\s*=\s*Timer\s*\(\s*Duration\s*\(\s*seconds:\s*seconds',
        ).hasMatch(service),
        isTrue,
      );

      expect(service, contains('_inAppTimers.remove(id)'));
      expect(service, contains('_inAppAlert?.call('));
    });

    test('registra agendamento nativo exactAllowWhileIdle', () {
      expect(
        service,
        contains(
          'AndroidScheduleMode.exactAllowWhileIdle',
        ),
      );
      expect(service, contains('_plugin.zonedSchedule('));
    });

    test(
      'permissão é solicitada somente no início explícito do timer',
      () {
        final bridgeStart = historialOwner.indexOf(
          'Future<void> startFromShiftConsumer',
        );
        final bridgeEnd = historialOwner.indexOf(
          'void cancelFromVisualConsumer',
          bridgeStart,
        );

        expect(bridgeStart, greaterThanOrEqualTo(0));
        expect(bridgeEnd, greaterThan(bridgeStart));

        final bridgeBlock = historialOwner.substring(bridgeStart, bridgeEnd);

        final permissionIndex = bridgeBlock.indexOf(
          'await NotificationService.requestPermission()',
        );
        final scheduleIndex = bridgeBlock.indexOf(
          'await NotificationService.scheduleTimer(',
        );

        expect(permissionIndex, greaterThanOrEqualTo(0));
        expect(scheduleIndex, greaterThan(permissionIndex));

        final startTimerStart = historialOwner.indexOf('void _startTimer');
        final startTimerEnd = historialOwner.indexOf(
          'void _cancelTimer',
          startTimerStart,
        );

        expect(startTimerStart, greaterThanOrEqualTo(0));
        expect(startTimerEnd, greaterThan(startTimerStart));

        final startTimerBlock =
            historialOwner.substring(startTimerStart, startTimerEnd);

        expect(
          startTimerBlock,
          isNot(
            contains(
              'NotificationService.requestPermission()',
            ),
          ),
        );
        expect(
          startTimerBlock,
          isNot(
            contains(
              'NotificationService.scheduleTimer(',
            ),
          ),
        );

        expect(
          shiftOwner,
          isNot(
            contains(
              'NotificationService.requestPermission()',
            ),
          ),
        );
      },
    );

    test('política iOS não solicita nem utiliza Critical Alerts', () {
      expect(
        RegExp(r'critical\s*:\s*true').hasMatch(service),
        isFalse,
      );
      expect(
        RegExp(r'InterruptionLevel\.critical').hasMatch(service),
        isFalse,
      );
      expect(
        RegExp(r'InterruptionLevel\.timeSensitive').hasMatch(service),
        isTrue,
      );
      expect(
        RegExp(r'InterruptionLevel\.active').hasMatch(service),
        isTrue,
      );
    });

    test('Timer usa alerta audível de lock screen sem full-screen invasivo', () {
      expect(service, contains("static const _chShift"));
      expect(service, contains("'medcases_shift'"));
      expect(service, contains('final isShiftTimer = channel == _chShift'));
      expect(service, contains('NotificationVisibility.public'));
      expect(service, contains('fullScreenIntent:   isShiftTimer ? false : true'));
      expect(service, contains('AndroidNotificationCategory.alarm'));
      expect(service, contains('playSound:          true'));
      expect(service, contains("sound:             'default'"));
      expect(service, contains('presentSound:      true'));
      expect(service, contains('InterruptionLevel.timeSensitive'));
      expect(service, contains('InterruptionLevel.active'));
    });

    test('Timer tenta exact e faz fallback inexact sem perder o alerta', () {
      final exact = service.indexOf('AndroidScheduleMode.exactAllowWhileIdle');
      final inexact =
          service.indexOf('AndroidScheduleMode.inexactAllowWhileIdle');

      expect(exact, greaterThanOrEqualTo(0));
      expect(inexact, greaterThan(exact));
      expect(service, contains('for (final scheduleMode in scheduleModes)'));
      expect(service, contains('return isShiftTimer ? -1 : id'));
    });

    test('countdown não cancela a notificação recém-agendada', () {
      final startTimerStart = historialOwner.indexOf(
        'void _startTimer(int seconds, String label)',
      );
      final cancelTimerStart = historialOwner.indexOf(
        'void _cancelTimer({bool updateUi = true})',
        startTimerStart,
      );

      expect(startTimerStart, greaterThanOrEqualTo(0));
      expect(cancelTimerStart, greaterThan(startTimerStart));

      final startTimerBlock = historialOwner.substring(
        startTimerStart,
        cancelTimerStart,
      );

      expect(startTimerBlock, isNot(contains('_cancelTimer();')));
      expect(startTimerBlock, contains('_countdownTimer?.cancel();'));
      expect(startTimerBlock, contains('_countdownTimer = null;'));
      expect(
        startTimerBlock,
        contains('countdown iniciado preservando notificationId='),
      );

      final scheduleIndex = historialOwner.indexOf(
        'final notifId = await NotificationService.scheduleTimer(',
      );
      final assignmentIndex = historialOwner.indexOf(
        '_notifId = notifId;',
        scheduleIndex,
      );
      final countdownIndex = historialOwner.indexOf(
        '_startTimer(seconds, timerLabel);',
        assignmentIndex,
      );

      expect(scheduleIndex, greaterThanOrEqualTo(0));
      expect(assignmentIndex, greaterThan(scheduleIndex));
      expect(countdownIndex, greaterThan(assignmentIndex));
    });

    test('copy do Timer usa Doc sem emoji em português e espanhol', () {
      final bridgeStart = historialOwner.indexOf(
        'Future<void> startFromShiftConsumer',
      );
      final bridgeEnd = historialOwner.indexOf(
        'void cancelFromVisualConsumer',
        bridgeStart,
      );

      expect(bridgeStart, greaterThanOrEqualTo(0));
      expect(bridgeEnd, greaterThan(bridgeStart));

      final bridge = historialOwner.substring(bridgeStart, bridgeEnd);

      expect(bridge, contains("'Hola Doc.'"));
      expect(bridge, contains("'Olá Doc.'"));
      expect(
        bridge,
        contains("'Es hora de revisar el paciente.'"),
      );
      expect(
        bridge,
        contains("'É hora de revisar o paciente.'"),
      );
      expect(bridge, isNot(contains('⏰')));
      expect(bridge, contains('title: notificationTitle'));
      expect(bridge, contains('body: notificationBody'));
      expect(bridge, contains('_startTimer(seconds, timerLabel)'));
    });

    test('Timer usa a paleta verde da Home V2 e remove o roxo legado', () {
      final sheetStart = home.indexOf(
        'class _PomodoroSheetState extends State<_PomodoroSheet>',
      );
      final sheetEnd = home.indexOf('// QUICK SHORTCUTS', sheetStart);
      expect(sheetStart, greaterThanOrEqualTo(0));
      expect(sheetEnd, greaterThan(sheetStart));

      final sheet = home.substring(sheetStart, sheetEnd);

      expect(
        sheet,
        contains('final palette = HomeV2Palette.resolve(widget.dark);'),
      );
      expect(sheet, contains('palette.accent'));
      expect(sheet, contains('palette.accentSoft'));
      expect(sheet, contains("'Timer clínico'"));
      expect(sheet, contains("'Temporizador clínico'"));
      expect(sheet, contains("'Programar revisão'"));
      expect(sheet, contains("'Programar revisión'"));
      expect(sheet, contains("'Revisão programada'"));
      expect(sheet, contains("'Revisión programada'"));
      expect(sheet, contains('OutlinedButton.icon('));
      expect(sheet, isNot(contains('0xFF7C3AED')));

      expect(
        historialOwner,
        contains('final timerPalette = HomeV2Palette.resolve(widget.dark);'),
      );
      expect(
        historialOwner,
        contains(
          '_timerActive ? timerPalette.accent : timerPalette.textMuted',
        ),
      );
    });

    test('overlay in-app não chama showDialog sem Navigator disponível', () {
      final overlayStart = service.indexOf(
        'class _NotificationOverlayState',
      );
      final overlayEnd = service.indexOf(
        'class _NotifDialog',
        overlayStart,
      );

      expect(overlayStart, greaterThanOrEqualTo(0));
      expect(overlayEnd, greaterThan(overlayStart));

      final overlay = service.substring(overlayStart, overlayEnd);

      expect(
        overlay,
        contains('WidgetsBinding.instance.addPostFrameCallback'),
      );
      expect(
        overlay,
        contains('Navigator.maybeOf('),
      );
      expect(
        overlay,
        contains('rootNavigator: true'),
      );
      expect(
        overlay,
        contains('final dialogContext = navigator?.overlay?.context'),
      );
      expect(
        overlay,
        contains('if (dialogContext == null)'),
      );
      expect(
        overlay,
        contains('alerta nativo preservado.'),
      );
      expect(
        overlay,
        contains('context: dialogContext'),
      );
      expect(
        overlay,
        contains('useRootNavigator: false'),
      );
      expect(
        overlay,
        isNot(contains('context:     context,')),
      );
    });
  });
}
