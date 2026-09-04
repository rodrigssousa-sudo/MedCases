import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('web notification stub mirrors native symbols used by service', () {
    final service = _read('lib/services/notification_service.dart');
    final stub = _read('lib/services/notification_web_stub.dart');

    expect(service, contains('NotificationVisibility.public'));
    expect(service, contains('NotificationVisibility.private'));
    expect(service, contains('visibility:'));
    expect(
      service,
      contains('AndroidScheduleMode.inexactAllowWhileIdle'),
    );

    expect(stub, contains('class NotificationVisibility'));
    expect(
      stub,
      contains('static const public = NotificationVisibility._();'),
    );
    expect(
      stub,
      contains('static const private = NotificationVisibility._();'),
    );
    expect(stub, contains('NotificationVisibility? visibility,'));
    expect(
      stub,
      contains(
        'static const inexactAllowWhileIdle = AndroidScheduleMode._();',
      ),
    );
  });

  test('web stub remains compile-only and does not add notification behavior',
      () {
    final stub = _read('lib/services/notification_web_stub.dart');

    expect(stub, contains('Future<bool?> initialize'));
    expect(stub, contains('async => false'));
    expect(stub, contains('Future<void> cancel(int id) async {}'));
    expect(stub, contains('Future<void> cancelAll() async {}'));

    for (final forbidden in <String>[
      'dart:html',
      'dart:js',
      'FirebaseMessaging',
      'HttpClient',
      'package:http',
      'api.openai.com',
    ]) {
      expect(stub, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
