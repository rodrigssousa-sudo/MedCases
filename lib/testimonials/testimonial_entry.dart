import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'testimonial_intent.dart';
import 'testimonial_screen.dart';

/// Placed inside the existing approved-user and professional declaration gates.
class TestimonialEntry extends StatefulWidget {
  const TestimonialEntry({super.key, required this.user, required this.child});
  final UserModel user;
  final Widget child;
  @override
  State<TestimonialEntry> createState() => _TestimonialEntryState();
}

class _TestimonialEntryState extends State<TestimonialEntry> {
  bool _open = false;
  @override
  void initState() {
    super.initState();
    TestimonialIntent.consume().then((requested) {
      if (mounted && requested) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) => _open
      ? TestimonialScreen(
          user: widget.user, onClose: () => setState(() => _open = false))
      : widget.child;
}
