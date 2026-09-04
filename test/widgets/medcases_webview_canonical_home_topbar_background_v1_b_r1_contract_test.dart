import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/widgets/medcases_webview_screen.dart',
    ).readAsStringSync();
  });

  test('WebView keeps canonical Home page backgrounds', () {
    expect(source, contains('const Color(0xFF1A1D23)'));
    expect(source, contains('const Color(0xFFE0E6E9)'));
  });

  test('Inner guide topbar keeps canonical True Liquid Glass geometry', () {
    final start = source.indexOf('appBar: PreferredSize(');
    final end = source.indexOf('body: _buildBody()', start);
    expect(start, isNonNegative);
    expect(end, greaterThan(start));

    final topbar = source.substring(start, end);

    expect(topbar, contains('preferredSize: const Size.fromHeight(48)'));
    expect(topbar, contains('height: 48'));
    expect(
      topbar,
      matches(
        RegExp(r'ImageFilter\.blur\(\s*sigmaX:\s*16,\s*sigmaY:\s*16\s*\)'),
      ),
    );
    expect(topbar, contains('blurRadius: 14'));
    expect(topbar, contains('spreadRadius: -8'));
    expect(topbar, contains('width: 0.7'));
  });

  test('Inner guide title is bilingual GUÍA CLÍNICA / GUIA CLÍNICO', () {
    expect(
      source,
      contains("final isEs = context.watch<AppProvider>().lang == 'es';"),
    );
    expect(source, contains("isEs ? 'GUÍA CLÍNICA' : 'GUIA CLÍNICO'"));
    expect(source, contains('fontSize: 16'));
    expect(source, contains('fontWeight: FontWeight.w900'));
    expect(source, contains('letterSpacing: 1.2'));

    final start = source.indexOf('appBar: PreferredSize(');
    final end = source.indexOf('body: _buildBody()', start);
    final topbar = source.substring(start, end);

    expect(topbar, isNot(contains("text: 'MEDCASES '")));
    expect(topbar, isNot(contains("text: 'PRO'")));
  });

  test('HTTPS badge stays hidden while HTTPS security remains', () {
    final start = source.indexOf('appBar: PreferredSize(');
    final end = source.indexOf('body: _buildBody()', start);
    final topbar = source.substring(start, end);

    expect(topbar, isNot(contains("'HTTPS'")));
    expect(topbar, isNot(contains('Icons.lock_rounded')));

    expect(source, contains("uri.scheme != 'https'"));
    expect(source, contains('BLOCKED non-HTTPS'));
    expect(source, contains('NavigationDecision.prevent'));
    expect(source, contains('NavigationDecision.navigate'));
  });

  test('runtime red-screen fix and WebView body remain intact', () {
    expect(source, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    expect(
      source,
      contains('WebViewController.fromPlatformCreationParams(params)'),
    );
    expect(source, contains('WebViewWidget(controller: _controller!)'));
    expect(source, contains('Icons.close_rounded'));
  });
}
