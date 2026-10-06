import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/config/legal_urls.dart';
import 'package:medcases/services/guide_navigation_intent.dart';
import 'package:medcases/widgets/public_landing/landing_message.dart';
import 'package:medcases/widgets/legal_links.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('external and noncatalog destinations cannot persist navigation',
      () async {
    for (final slug in [
      'https://evil.invalid',
      '../admin',
      'missing-guide',
      'meningitis-bacteriana-aguda?next=evil'
    ]) {
      expect(await GuideNavigationIntent.request(slug), isFalse);
      expect(await GuideNavigationIntent.pendingId(), isNull);
    }
  });
  test('canonical destination survives login/restart then clears once',
      () async {
    expect(await GuideNavigationIntent.request('meningitis-bacteriana-aguda'),
        isTrue);
    expect(await GuideNavigationIntent.pendingId(), 'meningite_bacteriana');
    expect(await GuideNavigationIntent.pendingId(), 'meningite_bacteriana');
    await GuideNavigationIntent.clear();
    expect(await GuideNavigationIntent.pendingId(), isNull);
  });
  test('expired or corrupt intent cannot open a destination', () async {
    SharedPreferences.setMockInitialValues({
      'medcases_guide_intent_v1': jsonEncode({
        'slug': 'meningitis-bacteriana-aguda',
        'at': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch
      })
    });
    expect(await GuideNavigationIntent.pendingId(), isNull);
    SharedPreferences.setMockInitialValues(
        {'medcases_guide_intent_v1': 'corrupt'});
    expect(await GuideNavigationIntent.pendingId(), isNull);
  });
  test('guide bridge validates type, language, shape and length', () {
    expect(
        landingGuideRequest(
            '{"type":"medcases:guide:v1","language":"es","slug":"meningitis-bacteriana-aguda"}'),
        ('meningitis-bacteriana-aguda', 'es'));
    for (final value in [
      '{}',
      '{"type":"medcases:guide:v1","language":"es","slug":"https://evil.invalid"}',
      '{"type":"medcases:guide:v1","language":"en","slug":"meningitis-bacteriana-aguda"}'
    ]) expect(landingGuideRequest(value), isNull);
  });
  testWidgets('paywall legal links fit mobile and localize PT/ES',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final es in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: MedCasesLegalLinks(isEs: es, compact: true))));
      expect(
          find.text(es ? 'Términos de uso' : 'Termos de Uso'), findsOneWidget);
      expect(
          find.text(es ? 'Política de privacidad' : 'Política de Privacidade'),
          findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });
  test('legal endpoints are canonical HTTPS permanent routes', () {
    for (final url in [
      MedCasesLegalUrls.privacy,
      MedCasesLegalUrls.terms,
      MedCasesLegalUrls.subscriptions,
      MedCasesLegalUrls.medicalDisclaimer,
      MedCasesLegalUrls.dataDeletion,
      MedCasesLegalUrls.support,
      MedCasesLegalUrls.contact
    ]) {
      final uri = Uri.parse(url);
      expect(uri.host, 'medcasespro.com');
      expect(uri.scheme, 'https');
      expect(uri.hasQuery, isFalse);
      expect(uri.path.endsWith('.html'), isFalse);
    }
  });
}
