import 'package:flutter/widgets.dart';

class PublicLanding extends StatelessWidget {
  const PublicLanding(
      {super.key,
      required this.onLogin,
      required this.onTestimonial,
      this.onGuide,
      required this.language});
  final ValueChanged<String> onLogin;
  final ValueChanged<String> onTestimonial;
  final String language;
  final void Function(String slug, String language)? onGuide;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
