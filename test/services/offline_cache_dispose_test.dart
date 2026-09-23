import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/offline_calculator_cache_service.dart';

void main() {
  testWidgets('dispose releases recurring offline scheduler', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = OfflineCalculatorCacheService.instance;
    cache.startBackgroundSync();
    await tester.pump();
    cache.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    // Flutter checks that no timer survives teardown; the old recurring timer
    // remains scheduled for the next eight-hour boundary and fails this test.
  });
}
