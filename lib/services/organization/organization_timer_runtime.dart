import 'organization_notifications.dart';
import 'organization_timer.dart';

class OrganizationTimerRuntime {
  static OrganizationTimerController? _controller;
  static MedCasesOrganizationNotifications? _alerts;
  static OrganizationTimerController get({required bool isEs}) {
    _alerts ??= MedCasesOrganizationNotifications(isEs: isEs);
    _alerts!.isEs = isEs;
    return _controller ??= OrganizationTimerController(
        store: PreferencesTimerStore(), alerts: _alerts!);
  }

  static String? get nativeStatus => _alerts?.nativeStatus;

  static Future<void> restore({required bool isEs}) =>
      get(isEs: isEs).restore();
  static Future<void> reconcile() async {
    await _controller?.reconcile();
  }
}
