import 'package:flutter/widgets.dart';

class PublicLanding extends StatelessWidget {
  const PublicLanding(
      {super.key,
      required this.onLogin,
      required this.onTestimonial,
      required this.language});
  final ValueChanged<String> onLogin;
  final ValueChanged<String> onTestimonial;
  final String language;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
