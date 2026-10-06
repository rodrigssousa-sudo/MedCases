import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agenda_event.dart';
import 'organization_notifications.dart';

class OrganizationDeviceCalendar {
  Future<String> save(AgendaEvent event, {required bool isEs}) async {
    if (kIsWeb) throw UnsupportedError('CALENDAR_MOBILE_ONLY');
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!(await Permission.calendarFullAccess.request()).isGranted) {
        throw StateError('CALENDAR_PERMISSION_DENIED');
      }
    }
    final id = await MedCasesOrganizationNotifications.native
        .invokeMethod<String>('saveCalendar', {
      'id': event.id,
      'owner': event.userId,
      'nativeId': event.deviceCalendarEventId,
      'title': event.title,
      'notes': event.notes,
      'startMs': event.startAt.millisecondsSinceEpoch,
      'endMs': (event.endAt ?? event.startAt.add(const Duration(hours: 1)))
          .millisecondsSinceEpoch,
      'recurrence': event.recurrence,
      'isEs': isEs,
    });
    if (id == null || id.isEmpty) throw StateError('CALENDAR_WRITE_FAILED');
    return id;
  }

  Future<void> delete(AgendaEvent event) async {
    if (kIsWeb || event.deviceCalendarEventId == null) return;
    await MedCasesOrganizationNotifications.native.invokeMethod<void>(
        'deleteCalendar', {
      'id': event.id,
      'owner': event.userId,
      'nativeId': event.deviceCalendarEventId
    });
  }
}
