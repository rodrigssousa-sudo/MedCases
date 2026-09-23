@TestOn('browser')
library;

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/widgets/public_landing/public_landing_web.dart';

void main() {
  testWidgets('origin and exact registered iframe isolate the message bridge',
      (tester) async {
    final registry = _RecordingRegistry(ui_web.platformViewRegistry);
    ui_web.debugOverridePlatformViewRegistry(registry);
    addTearDown(() => ui_web.debugOverridePlatformViewRegistry(null));
    final logins = <String>[];
    final testimonials = <String>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PublicLanding(
        language: 'pt',
        onLogin: logins.add,
        onTestimonial: testimonials.add,
      ),
    ));
    await tester.pump();
    final frame = registry.frame!;
    // Flutter's test surface may not composite platform views. Attach the
    // actual registered DOM element so Chrome creates its WindowProxy.
    if (frame.isConnected != true) html.document.body!.append(frame);
    const payload = '{"type":"medcases:login:v1","language":"pt-BR"}';
    void dispatch(String origin, JSAny? source, Object? data) {
      // Real DOM MessageEvent, including the native WindowProxy identity.
      final options = JSObject();
      options.setProperty('origin'.toJS, origin.toJS);
      options.setProperty('source'.toJS, source);
      options.setProperty('data'.toJS, data.jsify());
      final constructor = (html.window as JSObject)
          .getProperty<JSFunction>('MessageEvent'.toJS);
      final event =
          constructor.callAsConstructor<JSObject>('message'.toJS, options);
      html.window.dispatchEvent(event as html.Event);
    }

    final nativeSource =
        (frame as JSObject).getProperty<JSAny?>('contentWindow'.toJS);
    expect(nativeSource.isUndefinedOrNull, isFalse);
    dispatch(html.window.location.origin, html.window as JSObject, payload);
    dispatch(html.window.location.origin, null, payload);
    dispatch('https://untrusted.invalid', nativeSource, payload);
    for (final malformed in [
      null,
      '{',
      '{}',
      {'type': 'medcases:login:v1'}
    ]) {
      dispatch(html.window.location.origin, nativeSource, malformed);
    }
    await tester.pump();
    expect(logins, isEmpty);
    expect(testimonials, isEmpty);
    dispatch(html.window.location.origin, nativeSource, payload);
    dispatch(html.window.location.origin, nativeSource,
        '{"type":"medcases:testimonial:v1","language":"es"}');
    await tester.pump();
    expect(logins, ['pt']);
    expect(testimonials, ['es']);
    await tester.pumpWidget(const SizedBox());
    dispatch(html.window.location.origin, nativeSource, payload);
    await tester.pump();
    expect(logins, ['pt']);
    expect(testimonials, ['es']);
  });
}

// Observe the factory registration; keep the actual production DOM element and
// delegate registration to Flutter. No fabricated WindowProxy or security gate.
class _RecordingRegistry implements ui_web.PlatformViewRegistry {
  _RecordingRegistry(this.delegate);
  final ui_web.PlatformViewRegistry delegate;
  html.IFrameElement? frame;
  @override
  bool registerViewFactory(String viewType, Function viewFactory,
      {bool isVisible = true}) {
    if (viewType.startsWith('medcases-public-landing-')) {
      frame = Function.apply(viewFactory, [0]) as html.IFrameElement;
    }
    return delegate.registerViewFactory(viewType, viewFactory,
        isVisible: isVisible);
  }

  @override
  Object getViewById(int viewId) => delegate.getViewById(viewId);
}
