import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: MedTheme.light,
      darkTheme: MedTheme.dark,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: child,
          ),
        ),
      ),
    );
  }

  group('MedSection', () {
    testWidgets('renders header content and child', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedSection(
            title: 'Calculadoras',
            subtitle: 'Ferramentas clínicas',
            leading: Icon(MedIcons.calculator),
            trailing: Text('Ver todas'),
            child: Text('Conteúdo'),
          ),
        ),
      );

      expect(find.text('Calculadoras'), findsOneWidget);
      expect(find.text('Ferramentas clínicas'), findsOneWidget);
      expect(find.text('Ver todas'), findsOneWidget);
      expect(find.text('Conteúdo'), findsOneWidget);
      expect(find.byIcon(MedIcons.calculator), findsOneWidget);
    });

    testWidgets('renders child without optional header', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedSection(
            child: Text('Somente conteúdo'),
          ),
        ),
      );

      expect(find.text('Somente conteúdo'), findsOneWidget);
    });
  });

  group('MedHeader', () {
    testWidgets('renders complete header structure', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedHeader(
            eyebrow: 'MEDCASES NEXT',
            title: 'Olá, Bruno',
            subtitle: 'Seu auxiliar clínico',
            leading: Icon(MedIcons.person),
            actions: <Widget>[
              Icon(MedIcons.search),
              Icon(MedIcons.settings),
            ],
          ),
        ),
      );

      expect(find.text('MEDCASES NEXT'), findsOneWidget);
      expect(find.text('Olá, Bruno'), findsOneWidget);
      expect(find.text('Seu auxiliar clínico'), findsOneWidget);
      expect(find.byIcon(MedIcons.person), findsOneWidget);
      expect(find.byIcon(MedIcons.search), findsOneWidget);
      expect(find.byIcon(MedIcons.settings), findsOneWidget);
    });

    testWidgets('supports every official size', (tester) async {
      for (final size in MedHeaderSize.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedHeader(
              key: ValueKey<MedHeaderSize>(size),
              title: size.name,
              size: size,
            ),
          ),
        );

        expect(find.text(size.name), findsOneWidget);
      }
    });
  });

  group('MedEmptyState', () {
    testWidgets('renders title, message and icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedEmptyState(
            title: 'Nenhum resultado',
            message: 'Tente alterar os termos da busca.',
            icon: MedIcons.search,
          ),
        ),
      );

      expect(find.text('Nenhum resultado'), findsOneWidget);
      expect(
        find.text('Tente alterar os termos da busca.'),
        findsOneWidget,
      );
      expect(find.byIcon(MedIcons.search), findsOneWidget);
    });

    testWidgets('executes primary and secondary actions', (tester) async {
      var primary = 0;
      var secondary = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedEmptyState(
            title: 'Sem histórico',
            message: 'Ainda não há itens.',
            actionLabel: 'Adicionar',
            onAction: () => primary += 1,
            secondaryActionLabel: 'Cancelar',
            onSecondaryAction: () => secondary += 1,
          ),
        ),
      );

      await tester.tap(find.text('Adicionar'));
      await tester.pump();

      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('supports compact mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedEmptyState(
            title: 'Vazio',
            message: 'Sem conteúdo.',
            compact: true,
          ),
        ),
      );

      expect(find.text('Vazio'), findsOneWidget);
      expect(find.text('Sem conteúdo.'), findsOneWidget);
    });
  });

  group('MedLoading', () {
    testWidgets('renders circular loading by default', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedLoading(
            label: 'Carregando dados',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Carregando dados'), findsOneWidget);
    });

    testWidgets('renders linear determinate loading', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedLoading(
            variant: MedLoadingVariant.linear,
            value: 0.5,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(indicator.value, 0.5);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('supports every official size', (tester) async {
      for (final size in MedLoadingSize.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedLoading(
              key: ValueKey<MedLoadingSize>(size),
              size: size,
              label: size.name,
            ),
          ),
        );

        expect(find.text(size.name), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
    });
  });
}
