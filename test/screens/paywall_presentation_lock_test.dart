import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medcases/screens/upgrade_screen.dart';

class _SheetObserver extends NavigatorObserver {
  int sheets = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) sheets++;
  }
}

void main() {
  test('guard acquires synchronously, ignores duplicates and restores state',
      () async {
    final guard = PaywallPresentationGuard();
    final closed = Completer<void>();
    final states = <bool>[];
    var presentations = 0;
    final first = guard.run(() {
      presentations++;
      return closed.future;
    }, onChanged: () => states.add(guard.active));

    expect(guard.active, isTrue);
    await guard.run(() async => presentations++);
    expect(presentations, 1);
    closed.complete();
    await first;
    expect(guard.active, isFalse);
    expect(states, [true, false]);
    await guard.run(() async => presentations++);
    expect(presentations, 2);
  });

  test('finally restores input state on synchronous and asynchronous errors',
      () async {
    for (final asynchronous in [false, true]) {
      final guard = PaywallPresentationGuard();
      final states = <bool>[];
      await expectLater(
        guard.run(() {
          if (asynchronous) return Future<void>.error(StateError('present'));
          throw StateError('present');
        }, onChanged: () => states.add(guard.active)),
        throwsStateError,
      );
      expect(guard.active, isFalse);
      expect(states, [true, false]);
      await guard.run(() async {});
      expect(guard.active, isFalse);
    }
  });

  testWidgets('global helper ignores duplicates through the closing transition',
      (tester) async {
    final observer = _SheetObserver();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      }),
    ));

    var finished = false;
    final first = showUpgradeScreen(host).then((_) => finished = true);
    await showUpgradeScreen(host);
    expect(observer.sheets, 1);
    await tester.pumpAndSettle();
    expect(find.byType(UpgradeScreen), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(UpgradeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    Navigator.of(host).pop();
    await tester.pump();
    expect(finished, isFalse);
    await showUpgradeScreen(host);
    expect(observer.sheets, 1);
    await tester.pumpAndSettle();
    await first;
    expect(finished, isTrue);

    final reopened = showUpgradeScreen(host);
    await tester.pumpAndSettle();
    expect(observer.sheets, 2);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await reopened;
  });

  testWidgets('local lock stays acquired across a child sheet and restores',
      (tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      }),
    ));
    final localGuard = PaywallPresentationGuard();
    final flow = localGuard.run(() => showUpgradeScreen(host));
    await tester.pumpAndSettle();

    // Exercise nested navigation without invoking billing or faking a WebView.
    final upgradeContext = tester.element(find.byType(UpgradeScreen));
    final child = showModalBottomSheet<void>(
      context: upgradeContext,
      builder: (_) => const SizedBox(height: 100, child: Text('Child sheet')),
    );
    await tester.pumpAndSettle();
    expect(localGuard.active, isTrue);
    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    await child;
    expect(localGuard.active, isTrue);
    expect(find.byType(UpgradeScreen), findsOneWidget);

    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    await flow;
    expect(localGuard.active, isFalse);
  });

  testWidgets('failed presentation releases the global guard', (tester) async {
    late BuildContext invalidHost;
    await tester.pumpWidget(Builder(builder: (context) {
      invalidHost = context;
      return const SizedBox();
    }));
    await expectLater(
        showUpgradeScreen(invalidHost), throwsA(isA<FlutterError>()));

    late BuildContext host;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      host = context;
      return const Scaffold();
    })));
    final flow = showUpgradeScreen(host);
    await tester.pumpAndSettle();
    expect(find.byType(UpgradeScreen), findsOneWidget);
    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    await flow;
  });

  for (final dismissal in ['backdrop', 'back', 'swipe', 'navigator disposal']) {
    testWidgets('$dismissal releases the presentation lock', (tester) async {
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      })));
      final guard = PaywallPresentationGuard();
      final flow = guard.run(() => showUpgradeScreen(host));
      await tester.pumpAndSettle();

      switch (dismissal) {
        case 'backdrop':
          await tester.tapAt(const Offset(10, 10));
        case 'back':
          await tester.binding.handlePopRoute();
        case 'swipe':
          final top = tester.getTopLeft(find.byType(UpgradeScreen));
          await tester.flingFrom(
            top +
                Offset(
                    tester.getSize(find.byType(UpgradeScreen)).width / 2, 12),
            const Offset(0, 600),
            1500,
          );
        case 'navigator disposal':
          await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      expect(find.byType(UpgradeScreen), findsNothing);
      await flow;
      expect(guard.active, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposing the caller does not retain its context in the route',
      (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    late BuildContext host;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, show, __) => show
            ? Builder(builder: (context) {
                host = context;
                return const Scaffold();
              })
            : const SizedBox(),
      ),
    ));
    final flow = showUpgradeScreen(host);
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();
    expect(host.mounted, isFalse);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await flow;
    expect(tester.takeException(), isNull);
  });
}
