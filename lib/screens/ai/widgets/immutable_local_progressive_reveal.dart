import 'dart:async';

import 'package:flutter/material.dart';

class ImmutableLocalProgressiveReveal extends StatefulWidget {
  final String committedText;
  final TextStyle? style;
  final Duration tick;
  final int minimumCharactersPerTick;
  final int maximumCharactersPerTick;
  final Widget Function(BuildContext context, String visibleText) builder;

  const ImmutableLocalProgressiveReveal({
    super.key,
    required this.committedText,
    required this.builder,
    this.style,
    this.tick = const Duration(milliseconds: 18),
    this.minimumCharactersPerTick = 2,
    this.maximumCharactersPerTick = 18,
  });

  @override
  State<ImmutableLocalProgressiveReveal> createState() =>
      _ImmutableLocalProgressiveRevealState();
}

class _ImmutableLocalProgressiveRevealState
    extends State<ImmutableLocalProgressiveReveal> {
  Timer? _timer;
  late String _committedText;
  int _visibleLength = 0;

  @override
  void initState() {
    super.initState();
    _commit(widget.committedText);
  }

  @override
  void didUpdateWidget(covariant ImmutableLocalProgressiveReveal oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.committedText == oldWidget.committedText) return;

    // A new committed response is a new immutable reveal session.
    _commit(widget.committedText);
  }

  void _commit(String value) {
    _timer?.cancel();
    _committedText = value;
    _visibleLength = 0;

    if (_committedText.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    _timer = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;

      final remaining = _committedText.length - _visibleLength;
      if (remaining <= 0) {
        _timer?.cancel();
        return;
      }

      final adaptive = (_committedText.length / 120).ceil();
      final step = adaptive.clamp(
        widget.minimumCharactersPerTick,
        widget.maximumCharactersPerTick,
      );

      setState(() {
        _visibleLength =
            (_visibleLength + step).clamp(0, _committedText.length);
      });

      if (_visibleLength >= _committedText.length) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleText = _committedText.substring(
      0,
      _visibleLength.clamp(0, _committedText.length),
    );
    return widget.builder(context, visibleText);
  }
}
