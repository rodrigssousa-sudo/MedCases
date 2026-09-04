// MEDCASES_HOME_CARD_OPEN_TRANSITION_UNIFICATION_WEB_MOBILE_V1_B_R3
import 'package:flutter/material.dart';

/// Canonical opening motion for destinations launched from the MedCases Home.
///
/// Contract:
/// - Web and native use the same bottom -> top direction.
/// - Navigator routes reverse top -> bottom when popped.
/// - MainShell tab workspaces remain mounted; this helper animates the existing
///   IndexedStack/Navigator surface instead of replacing its children.
abstract final class HomeCardTransition {
  static const Duration forwardDuration = Duration(milliseconds: 240);
  static const Duration reverseDuration = Duration(milliseconds: 220);

  static const Offset entryOffset = Offset(0, 1);

  static const AnimationStyle modalAnimationStyle = AnimationStyle(
    duration: forwardDuration,
    reverseDuration: reverseDuration,
  );

  static Route<T> route<T>({
    required WidgetBuilder builder,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: forwardDuration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: entryOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}

/// Animates a MainShell workspace change without replacing the persistent
/// `_staticScreens` tree.
///
/// The child remains an IndexedStack or the isolated 40% Navigator; only its
/// presentation surface moves. This preserves stateful clinical workspaces.
class HomeCardWorkspaceTransition extends StatefulWidget {
  const HomeCardWorkspaceTransition({
    required this.transitionKey,
    required this.child,
    super.key,
  });

  final int transitionKey;
  final Widget child;

  @override
  State<HomeCardWorkspaceTransition> createState() =>
      _HomeCardWorkspaceTransitionState();
}

class _HomeCardWorkspaceTransitionState
    extends State<HomeCardWorkspaceTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();

    // First frame is already visible; opening animation starts only when the
    // selected Home destination actually changes.
    _controller = AnimationController(
      vsync: this,
      duration: HomeCardTransition.forwardDuration,
      reverseDuration: HomeCardTransition.reverseDuration,
      value: 1,
    );

    _position = Tween<Offset>(
      begin: HomeCardTransition.entryOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HomeCardWorkspaceTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transitionKey != widget.transitionKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _position,
      child: widget.child,
    );
  }
}
