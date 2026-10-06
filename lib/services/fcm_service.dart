import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'notifications/notification_contract.dart';
import 'notification_service.dart';

/// One listener set per process, one device locale, no clinical notification copy.
class FcmService {
  FcmService._();
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _opened, _foreground;
  static String? _uid;
  static String _locale = 'pt';
  static int _epoch = 0;
  static Timer? _retry;
  static int _retryCount = 0;
  static bool _localTapBound = false;
  static Future<void> _writes = Future.value();
  static final pendingDestination =
      ValueNotifier<NotificationDestination?>(null);
  static void Function(Map<String, dynamic>)? _adminTap;
  static void setOnAdminNotifTap(void Function(Map<String, dynamic>) cb) =>
      _adminTap = cb;
  static Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('notification.installation');
    if (id == null) {
      final random = Random.secure();
      id = sha256
          .convert(List.generate(32, (_) => random.nextInt(256)))
          .toString();
      await prefs.setString('notification.installation', id);
    }
    return id;
  }

  static Future<void> init({required String uid, String locale = 'pt'}) async {
    if (kIsWeb ||
        ![TargetPlatform.iOS, TargetPlatform.android]
            .contains(defaultTargetPlatform)) return;
    _retry?.cancel();
    _retryCount = 0;
    _uid = uid;
    _locale = NotificationContract.locale(locale);
    _epoch++;
    _refresh ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((_) => unawaited(_sync()));
    _opened ??=
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _tap(m.data));
    _foreground ??= FirebaseMessaging.onMessage.listen((m) async {
      debugPrint('[NOTIFICATIONS] FOREGROUND_MESSAGE_RECEIVED');
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await NotificationService.showForegroundPush(m.data, _locale, title: m.notification?.title, body: m.notification?.body);
        } catch (_) {
          debugPrint('[NOTIFICATIONS] FOREGROUND_PRESENTATION_FAILED');
        }
      }
    });
    if (!_localTapBound) {
      _localTapBound = true;
      NotificationService.remoteTap.addListener(() {
        final target = NotificationService.remoteTap.value;
        if (target != null) {
          pendingDestination.value = target;
          NotificationService.remoteTap.value = null;
        }
      });
      final target = NotificationService.remoteTap.value;
      if (target != null) {
        pendingDestination.value = target;
        NotificationService.remoteTap.value = null;
      }
    }
    // iOS presents remotely; Android presents once through its native channel.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: true, badge: false, sound: true);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _tap(initial.data);
    await _sync();
  }

  static void _tap(Map<String, dynamic> data) {
    if (data['route'] == '/admin/notifications') {
      _adminTap?.call(data);
      return;
    }
    final target = NotificationDestination.parse(data);
    if (target != null) pendingDestination.value = target;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    await _sync();
  }

  static Future<void> updateLocale(String locale) async {
    _locale = NotificationContract.locale(locale);
    await _sync();
  }

  static Future<void> updatePreferences(
      NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'notification.preferences', jsonEncode(preferences.toJson()));
    await _sync();
  }

  static void _retrySync(int epoch) {
    if (epoch != _epoch || _retryCount >= 3 || _retry?.isActive == true) return;
    _retryCount++;
    _retry = Timer(Duration(seconds: 5 * _retryCount), () {
      if (epoch == _epoch) unawaited(_sync());
    });
  }

  static Future<void> _sync() {
    final epoch = _epoch, uid = _uid;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (kIsWeb ||
          uid == null ||
          epoch != _epoch ||
          FirebaseAuth.instance.currentUser?.uid != uid) return;
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
            settings.authorizationStatus == AuthorizationStatus.denied) return;
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            await FirebaseMessaging.instance.getAPNSToken() == null) {
          debugPrint('[NOTIFICATIONS] APNS_TOKEN_PENDING');
          _retrySync(epoch);
          return;
        }
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null ||
            epoch != _epoch ||
            FirebaseAuth.instance.currentUser?.uid != uid) return;
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('notification.preferences');
        await FirebaseFunctions.instance
            .httpsCallable('registerNotificationDevice')
            .call({
          'installationId': await installationId(),
          'token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'activeAppLocale': _locale,
          'campaignPushV2': true,
          'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'preferences': raw == null
              ? const NotificationPreferences().toJson()
              : jsonDecode(raw),
        });
        debugPrint(
            '[NOTIFICATIONS] DEVICE_REGISTERED platform=${defaultTargetPlatform.name} locale=$_locale tokenHash=${sha256.convert(utf8.encode(token)).toString().substring(0, 12)} permission=${settings.authorizationStatus.name}');
      } catch (_) {
        debugPrint('[NOTIFICATIONS] registration_pending');
        _retrySync(epoch);
      }
    });
    return _writes;
  }

  static Future<void> deleteToken(String uid) {
    _retry?.cancel();
    _uid = null;
    final epoch = ++_epoch;
    pendingDestination.value = null;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (kIsWeb || epoch != _epoch || _uid != null) return;
      final installation = await installationId();
      if (epoch != _epoch || _uid != null) return;
      try {
        if (FirebaseAuth.instance.currentUser?.uid == uid) {
          await FirebaseFunctions.instance
              .httpsCallable('unregisterNotificationDevice')
              .call({'installationId': installation});
        }
      } catch (_) {
        debugPrint('[NOTIFICATIONS] unregister_pending');
      }
      if (epoch != _epoch || _uid != null) return;
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    });
    return _writes;
  }
}
