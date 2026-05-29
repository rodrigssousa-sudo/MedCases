// notification_web_stub.dart
// Stub para compilação Web — flutter_local_notifications não existe no browser.
// Exporta apenas os símbolos usados em notification_service.dart.
// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:typed_data';

class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize(dynamic s, {
    dynamic onDidReceiveNotificationResponse,
    dynamic onDidReceiveBackgroundNotificationResponse,
  }) async => false;
  Future<void> cancel(int id) async {}
  Future<void> cancelAll() async {}
  Future<void> zonedSchedule(int id, String? title, String? body,
    dynamic scheduledDate, dynamic details, {
    String? payload,
    dynamic androidScheduleMode,
    dynamic uiLocalNotificationDateInterpretation,
  }) async {}
  T? resolvePlatformSpecificImplementation<T>() => null;
}

class InitializationSettings {
  const InitializationSettings({dynamic android, dynamic iOS, dynamic macOS});
}
class AndroidInitializationSettings {
  const AndroidInitializationSettings(String icon);
}
class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    bool requestAlertPermission = true,
    bool requestBadgePermission = true,
    bool requestSoundPermission = true,
  });
}
class NotificationDetails {
  const NotificationDetails({dynamic android, dynamic iOS, dynamic macOS});
}
class AndroidNotificationDetails {
  const AndroidNotificationDetails(String channelId, String channelName, {
    String? channelDescription,
    dynamic importance,
    dynamic priority,
    dynamic sound,
    bool playSound = true,
    bool enableVibration = true,
    Int64List? vibrationPattern,
    dynamic category,
    bool fullScreenIntent = false,
    bool autoCancel = true,
    dynamic styleInformation,
  });
}
class DarwinNotificationDetails {
  const DarwinNotificationDetails({
    String? sound,
    bool presentAlert = true,
    bool presentBadge = true,
    bool presentSound = true,
    dynamic interruptionLevel,
  });
}
class AndroidNotificationChannel {
  final String id;
  final String name;
  const AndroidNotificationChannel(this.id, this.name, {
    String? description,
    dynamic importance,
    bool playSound = true,
    bool enableVibration = true,
  });
}
class AndroidNotificationCategory {
  static const alarm = AndroidNotificationCategory._();
  const AndroidNotificationCategory._();
}
class RawResourceAndroidNotificationSound {
  const RawResourceAndroidNotificationSound(String name);
}
class BigTextStyleInformation {
  const BigTextStyleInformation(String text);
}
class Importance {
  static const max = Importance._();
  const Importance._();
}
class Priority {
  static const high = Priority._();
  const Priority._();
}
class AndroidScheduleMode {
  static const exactAllowWhileIdle = AndroidScheduleMode._();
  const AndroidScheduleMode._();
}
class UILocalNotificationDateInterpretation {
  static const absoluteTime = UILocalNotificationDateInterpretation._();
  const UILocalNotificationDateInterpretation._();
}
class InterruptionLevel {
  static const timeSensitive = InterruptionLevel._();
  const InterruptionLevel._();
}
class NotificationResponse {
  final String? payload;
  const NotificationResponse({this.payload});
}
class IOSFlutterLocalNotificationsPlugin {
  Future<bool?> requestPermissions({
    bool alert = false, bool badge = false, bool sound = false,
  }) async => false;
}
class AndroidFlutterLocalNotificationsPlugin {
  Future<bool?> requestNotificationsPermission() async => false;
  Future<void> createNotificationChannel(AndroidNotificationChannel ch) async {}
}
