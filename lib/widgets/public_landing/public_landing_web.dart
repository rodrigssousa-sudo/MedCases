// Conditional web implementation; never imported by native builds.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import '../../testimonials/testimonial_service.dart';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'landing_message.dart';

class PublicLanding extends StatefulWidget {
  const PublicLanding(
      {super.key,
      required this.onLogin,
      required this.onTestimonial,
      required this.language});
  final ValueChanged<String> onLogin;
  final ValueChanged<String> onTestimonial;
  final String language;
  @override
  State<PublicLanding> createState() => _PublicLandingState();
}

class _PublicLandingState extends State<PublicLanding> {
  static int _nextId = 0;
  late final String _viewType;
  late final html.IFrameElement _frame;
  StreamSubscription<html.MessageEvent>? _messages;
  final _testimonials = TestimonialService();
  Future<void> _sendTestimonials() async {
    try {
      final rows = await _testimonials.published();
      if (!mounted) return;
      _frame.contentWindow?.postMessage(
          jsonEncode({
            'type': 'medcases:testimonials:v1',
            'rows': rows.take(12).map((r) => r.data).toList()
          }),
          html.window.location.origin);
    } catch (_) {
      if (mounted) {
        _frame.contentWindow?.postMessage(
            jsonEncode({'type': 'medcases:testimonials:v1', 'error': true}),
            html.window.location.origin);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'medcases-public-landing-${_nextId++}';
    final uri = Uri.parse(html.document.baseUri!)
        .resolve('assets/assets/public_landing/index.html')
        .replace(queryParameters: {
      'lang': widget.language == 'pt' ? 'pt-BR' : 'es'
    });
    _frame = html.IFrameElement()
      ..src = uri.toString()
      ..title = 'MedCases Pro'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _frame.setAttribute('allow', 'autoplay');
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
    _messages = html.window.onMessage.listen((event) {
      // dart:html MessageEvent.source returns null for cross-frame WindowBase
      // wrappers. Compare the native windows, preserving exact source isolation.
      final source = (event as JSObject).getProperty<JSAny?>('source'.toJS);
      final frameWindow =
          (_frame as JSObject).getProperty<JSAny?>('contentWindow'.toJS);
      if (!mounted ||
          event.origin != html.window.location.origin ||
          source.isUndefinedOrNull ||
          frameWindow.isUndefinedOrNull ||
          !source.strictEquals(frameWindow).toDart) {
        return;
      }
      final language = landingLoginLanguage(event.data);
      if (language != null) widget.onLogin(language);
      final testimonialLanguage =
          landingActionLanguage(event.data, 'medcases:testimonial:v1');
      if (testimonialLanguage != null) {
        widget.onTestimonial(testimonialLanguage);
      }
      if (landingActionLanguage(event.data, 'medcases:testimonials-ready:v1') !=
          null) {
        _sendTestimonials();
      }
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    _testimonials.dispose();
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
