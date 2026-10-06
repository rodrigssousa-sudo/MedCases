import '../entitlement_service.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';
import 'organization_timer.dart';

enum OrganizationPermission { unknown, granted, denied, systemDisabled }

class MedCasesOrganizationNotifications implements OrganizationTimerAlerts {
  MedCasesOrganizationNotifications({required this.isEs});
  bool isEs;
  static const timerId = 700001;
  static StreamSubscription<User?>? _ownerSubscription;
  static Future<void> _ownerWork = Future.value();
  static Future<void> cancelRegisteredAgenda() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in prefs.getStringList('organization_agenda_reminder_ids') ??
        <String>[]) {
      await NotificationService.cancelOrganization(agendaId(id));
    }
    await prefs.remove('organization_agenda_reminder_ids');
    await prefs.remove('organization_agenda_reminder_owner');
  }

  static void watchAgendaOwner() {
    _ownerSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) {
      _ownerWork = _ownerWork.catchError((Object _) {}).then((_) async {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('organization_agenda_reminder_owner') !=
            user?.uid) {
          for (final id
              in prefs.getStringList('organization_agenda_reminder_ids') ??
                  <String>[]) {
            await NotificationService.cancelOrganization(agendaId(id));
          }
          await prefs.remove('organization_agenda_reminder_owner');
          await prefs.remove('organization_agenda_reminder_ids');
        }
      });
    });
  }

  String? nativeStatus;
  static const native = MethodChannel('medcases/organization_v1');
  static int agendaId(String id) {
    // Stable across isolates and app restarts; reserved range excludes legacy IDs.
    var hash = 2166136261;
    for (final c in id.codeUnits) {
      hash = ((hash ^ c) * 16777619) & 0x7fffffff;
    }
    return 800000 + hash % 1000000000;
  }

  Future<OrganizationPermission> getPermissionStatus() async {
    if (kIsWeb) return OrganizationPermission.systemDisabled;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status =
          await native.invokeMethod<String>('notificationPermission');
      return switch (status) {
        'authorized' ||
        'provisional' ||
        'ephemeral' =>
          OrganizationPermission.granted,
        'notDetermined' => OrganizationPermission.unknown,
        'denied' => OrganizationPermission.systemDisabled,
        _ =>
          throw PlatformException(code: 'NOTIFICATION_PERMISSION_UNAVAILABLE'),
      };
    }
    final status = await Permission.notification.status;
    if (status.isGranted || status.isProvisional) {
      return OrganizationPermission.granted;
    }
    final asked = (await SharedPreferences.getInstance())
            .getBool('organization_notification_asked') ??
        false;
    if (!asked && !status.isPermanentlyDenied) {
      return OrganizationPermission.unknown;
    }
    return status.isPermanentlyDenied
        ? OrganizationPermission.systemDisabled
        : OrganizationPermission.denied;
  }

  Future<OrganizationPermission> requestPermission() async {
    final current = await getPermissionStatus();
    if (current != OrganizationPermission.unknown) return current;
    await (await SharedPreferences.getInstance())
        .setBool('organization_notification_asked', true);
    await NotificationService.requestPermission();
    return getPermissionStatus();
  }

  Future<void> openSystemSettings() async {
    if (!kIsWeb) await openAppSettings();
  }

  @override
  Future<void> schedule(OrganizationTimerState state) async {
    if (await getPermissionStatus() != OrganizationPermission.granted) return;
    await NotificationService.scheduleOrganization(
        id: timerId,
        at: state.targetEndTime!,
        title: 'Timer finalizado',
        body: isEs
            ? 'El tiempo configurado en MedCases terminó.'
            : 'O tempo configurado no MedCases terminou.',
        payload: 'organization:timer');
  }

  @override
  Future<void> cancel() async {
    await NotificationService.cancelOrganization(timerId);
    if (!kIsWeb) {
      try {
        await native.invokeMethod<void>('endTimer');
      } on MissingPluginException {
        nativeStatus = 'NATIVE_UNSUPPORTED';
      } on PlatformException catch (e) {
        nativeStatus = e.code;
      }
    }
  }

  @override
  Future<void> present(OrganizationTimerState state) async {
    if (kIsWeb) return;
    try {
      await native
          .invokeMethod<void>('timer', {...state.toJson(), 'isEs': isEs});
      nativeStatus = null;
    } on MissingPluginException {
      nativeStatus = 'NATIVE_UNSUPPORTED';
    } on PlatformException catch (e) {
      nativeStatus = e.code;
    }
  }

  Future<void> scheduleAgendaReminder(
      {required String id,
      required String owner,
      required DateTime at,
      required String title}) async {
    if (!at.isAfter(DateTime.now()) ||
        await getPermissionStatus() != OrganizationPermission.granted) {
      return;
    }
    if (!EntitlementService.instance.can(MedCasesCapability.agenda) ||
        FirebaseAuth.instance.currentUser?.uid != owner) {
      throw StateError('AGENDA_OWNER_CHANGED');
    }
    final prefs = await SharedPreferences.getInstance();
    final registered =
        (prefs.getStringList('organization_agenda_reminder_ids') ?? <String>[])
            .toSet()
          ..add(id);
    await prefs.setString('organization_agenda_reminder_owner', owner);
    await prefs.setStringList(
        'organization_agenda_reminder_ids', registered.toList());
    if (!EntitlementService.instance.can(MedCasesCapability.agenda) ||
        FirebaseAuth.instance.currentUser?.uid != owner) {
      throw StateError('AGENDA_OWNER_CHANGED');
    }
    await NotificationService.scheduleOrganization(
        id: agendaId(id),
        at: at,
        title: isEs ? 'Recordatorio de Agenda' : 'Lembrete da Agenda',
        body: title,
        payload: 'organization:agenda');
    if (!EntitlementService.instance.can(MedCasesCapability.agenda) ||
        FirebaseAuth.instance.currentUser?.uid != owner) {
      await cancelAgendaReminder(id);
      throw StateError('AGENDA_OWNER_CHANGED');
    }
  }

  Future<void> cancelAgendaReminder(String id) =>
      NotificationService.cancelOrganization(agendaId(id));
}
