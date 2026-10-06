import 'package:flutter/material.dart';

class RecordingSessionOverlay extends StatelessWidget {
  const RecordingSessionOverlay(
      {super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  Widget build(BuildContext context) => child;
}
