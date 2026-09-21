import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/screens/login_screen.dart';

void main() {
  testWidgets('landing back remains tappable above login content', (tester) async {
    SharedPreferences.setMockInitialValues({'lang': 'es'});
    var returns = 0;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(onBack: () => returns++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(returns, 1);
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    expect(returns, 2);
  });
}
