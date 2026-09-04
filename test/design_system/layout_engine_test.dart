import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Future<void> pumpTestApp(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MedTheme.light,
        darkTheme: MedTheme.dark,
        home: child,
      ),
    );
  }

  group('MedResponsiveBuilder', () {
    testWidgets('resolves mobile window class', (tester) async {
      MedWindowClass? resolved;

      await pumpTestApp(
        tester,
        SizedBox(
          width: 390,
          child: MedResponsiveBuilder(
            builder: (context, windowClass, constraints) {
              resolved = windowClass;
              return const SizedBox();
            },
          ),
        ),
        size: const Size(390, 844),
      );

      expect(resolved, MedWindowClass.mobile);
    });

    testWidgets('resolves tablet window class', (tester) async {
      MedWindowClass? resolved;

      await pumpTestApp(
        tester,
        SizedBox(
          width: 768,
          child: MedResponsiveBuilder(
            builder: (context, windowClass, constraints) {
              resolved = windowClass;
              return const SizedBox();
            },
          ),
        ),
        size: const Size(768, 1024),
      );

      expect(resolved, MedWindowClass.tablet);
    });

    testWidgets('resolves desktop window class', (tester) async {
      MedWindowClass? resolved;

      await pumpTestApp(
        tester,
        SizedBox(
          width: 1280,
          child: MedResponsiveBuilder(
            builder: (context, windowClass, constraints) {
              resolved = windowClass;
              return const SizedBox();
            },
          ),
        ),
        size: const Size(1280, 800),
      );

      expect(resolved, MedWindowClass.desktop);
    });

    testWidgets('resolves wide desktop window class', (tester) async {
      MedWindowClass? resolved;

      await pumpTestApp(
        tester,
        SizedBox(
          width: 1600,
          child: MedResponsiveBuilder(
            builder: (context, windowClass, constraints) {
              resolved = windowClass;
              return const SizedBox();
            },
          ),
        ),
        size: const Size(1600, 900),
      );

      expect(resolved, MedWindowClass.wideDesktop);
    });
  });

  group('MedContentLayout', () {
    testWidgets('renders centered constrained content', (tester) async {
      await pumpTestApp(
        tester,
        const Scaffold(
          body: MedContentLayout(
            maxWidth: 600,
            child: Text('Conteúdo'),
          ),
        ),
        size: const Size(1200, 800),
      );

      expect(find.text('Conteúdo'), findsOneWidget);

      final Size size = tester.getSize(
        find.byType(MedContentLayout),
      );

      expect(size.width, 1200);
    });

    test('official content widths remain progressive', () {
      expect(
        MedContentWidth.compact,
        lessThan(MedContentWidth.standard),
      );
      expect(
        MedContentWidth.standard,
        lessThan(MedContentWidth.expanded),
      );
      expect(
        MedContentWidth.expanded,
        lessThan(MedContentWidth.wide),
      );
    });
  });

  group('MedSafeArea', () {
    testWidgets('delegates official safe area configuration', (tester) async {
      await pumpTestApp(
        tester,
        const Scaffold(
          body: MedSafeArea(
            left: false,
            bottom: false,
            child: Text('Seguro'),
          ),
        ),
        size: const Size(390, 844),
      );

      final SafeArea safeArea = tester.widget<SafeArea>(
        find.byType(SafeArea),
      );

      expect(safeArea.left, isFalse);
      expect(safeArea.top, isTrue);
      expect(safeArea.right, isTrue);
      expect(safeArea.bottom, isFalse);
      expect(find.text('Seguro'), findsOneWidget);
    });
  });

  group('MedPageLayout', () {
    testWidgets('renders header, body, footer and floating action', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        MedPageLayout(
          header: AppBar(
            title: const Text('Cabeçalho'),
          ),
          footer: const Text('Rodapé'),
          floatingActionButton: const Icon(Icons.add),
          child: const Text('Corpo'),
        ),
        size: const Size(390, 844),
      );

      expect(find.text('Cabeçalho'), findsOneWidget);
      expect(find.text('Corpo'), findsOneWidget);
      expect(find.text('Rodapé'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('supports unconstrained page content', (tester) async {
      await pumpTestApp(
        tester,
        const MedPageLayout(
          centerContent: false,
          useSafeArea: false,
          child: Text('Livre'),
        ),
        size: const Size(390, 844),
      );

      expect(find.text('Livre'), findsOneWidget);
      expect(find.byType(MedContentLayout), findsNothing);
    });
  });

  group('MedGrid', () {
    List<Widget> items() {
      return List<Widget>.generate(
        8,
        (index) => Container(
          key: ValueKey<int>(index),
          child: Text('Item $index'),
        ),
      );
    }

    testWidgets('uses one column on mobile', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 390,
            child: MedGrid(
              children: items(),
            ),
          ),
        ),
        size: const Size(390, 844),
      );

      final GridView grid = tester.widget<GridView>(
        find.byType(GridView),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 1);
    });

    testWidgets('uses two columns on tablet', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 768,
            child: MedGrid(
              children: items(),
            ),
          ),
        ),
        size: const Size(768, 1024),
      );

      final GridView grid = tester.widget<GridView>(
        find.byType(GridView),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('uses three columns on desktop', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 1280,
            child: MedGrid(
              children: items(),
            ),
          ),
        ),
        size: const Size(1280, 800),
      );

      final GridView grid = tester.widget<GridView>(
        find.byType(GridView),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('uses four columns on wide desktop', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 1600,
            child: MedGrid(
              children: items(),
            ),
          ),
        ),
        size: const Size(1600, 900),
      );

      final GridView grid = tester.widget<GridView>(
        find.byType(GridView),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 4);
    });

    test('custom grid columns resolve every window class', () {
      const columns = MedGridColumns(
        mobile: 2,
        tablet: 3,
        desktop: 4,
        wideDesktop: 6,
      );

      expect(columns.resolve(MedWindowClass.mobile), 2);
      expect(columns.resolve(MedWindowClass.tablet), 3);
      expect(columns.resolve(MedWindowClass.desktop), 4);
      expect(columns.resolve(MedWindowClass.wideDesktop), 6);
    });
  });
}
