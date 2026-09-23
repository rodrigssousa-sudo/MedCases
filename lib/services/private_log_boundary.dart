import 'dart:async';
import 'package:flutter/foundation.dart';

/// Release diagnostics may never forward unstructured application/plugin text.
/// Deliberately emits only fixed event codes; clinical values, exception bodies,
/// request IDs supplied by callers, and paths are not treated as safe metadata.
Future<void> runWithPrivateLogBoundary(Future<void> Function() body) async {
  if (!kReleaseMode) {
    await body();
    return;
  }
  final done = Completer<void>();
  runZonedGuarded<void>(() {
    debugPrint = (String? message, {int? wrapWidth}) {
      Zone.current.print('MEDCASES_DIAGNOSTIC_REDACTED');
    };
    body().then((_) {
      if (!done.isCompleted) done.complete();
    }, onError: (Object _, StackTrace __) {
      Zone.current.print('MEDCASES_BOOT_ERROR');
      if (!done.isCompleted) done.complete();
    });
  }, (Object _, StackTrace __) {
    debugPrint('MEDCASES_ASYNC_ERROR');
    if (!done.isCompleted) done.complete();
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
    parent.print(zone, 'MEDCASES_DIAGNOSTIC_REDACTED');
  }));
  await done.future;
}
