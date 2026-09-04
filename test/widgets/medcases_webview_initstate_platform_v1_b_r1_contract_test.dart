import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/widgets/medcases_webview_screen.dart',
    ).readAsStringSync();
  });

  test('defaultTargetPlatform is available to the WebView source', () {
    final foundationImport = RegExp(
      r"import 'package:flutter/foundation\.dart'"
      r"(?:\s+show\s+([^;]+))?;",
    ).firstMatch(source);

    expect(foundationImport, isNotNull);

    final showList = foundationImport!.group(1);
    if (showList != null) {
      final names = showList.split(',').map((e) => e.trim()).toSet();
      expect(names, contains('defaultTargetPlatform'));
    }
  });

  test('iOS detection no longer reads Theme.of during initState path', () {
    expect(source, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    expect(
      source,
      isNot(contains('Theme.of(context).platform == TargetPlatform.iOS')),
    );
    expect(source, contains('final bool isIOS = _detectIOS();'));
  });

  test('controller creation and provider lifecycle remain unchanged', () {
    expect(source, contains('final p = context.read<AppProvider>();'));
    expect(source, contains('p.addListener(_onProviderChanged);'));
    expect(source, contains('WebKitWebViewControllerCreationParams('));
    expect(
      source,
      contains('WebViewController.fromPlatformCreationParams(params)'),
    );
    expect(source, contains('..loadRequest(uri);'));
    expect(
      source,
      contains(
        'context.read<AppProvider>().removeListener(_onProviderChanged);',
      ),
    );
  });

  test('HTTPS and navigation protections remain intact', () {
    expect(source, contains("uri.scheme != 'https'"));
    expect(source, contains('JavaScriptMode.unrestricted'));
    expect(source, contains('onNavigationRequest: (request)'));
    expect(source, contains("dest.scheme == 'javascript'"));
    expect(source, contains('NavigationDecision.prevent'));
    expect(source, contains('NavigationDecision.navigate'));
  });
}
