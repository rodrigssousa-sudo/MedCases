import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Future<void> pumpTestApp(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: MedTheme.light,
        darkTheme: MedTheme.dark,
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );

    await tester.pump();
  }

  group('MedDialog', () {
    testWidgets('renders title, content and actions', (tester) async {
      var primary = 0;
      var secondary = 0;

      await pumpTestApp(
        tester,
        MedDialog(
          title: 'Confirmar ação',
          content: const Text('Deseja continuar?'),
          primaryActionLabel: 'Confirmar',
          onPrimaryAction: () => primary += 1,
          secondaryActionLabel: 'Cancelar',
          onSecondaryAction: () => secondary += 1,
        ),
      );

      expect(find.text('Confirmar ação'), findsOneWidget);
      expect(find.text('Deseja continuar?'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(MedButton, 'Confirmar'),
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(MedButton, 'Cancelar'),
      );
      await tester.pump();

      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedDialogVariant.values) {
        await pumpTestApp(
          tester,
          MedDialog(
            key: ValueKey<MedDialogVariant>(variant),
            title: variant.name,
            content: const Text('Conteúdo'),
            variant: variant,
            showCloseButton: false,
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });

    testWidgets('static show opens and closes dialog', (tester) async {
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                MedDialog.show<void>(
                  context: context,
                  title: 'Diálogo aberto',
                  content: const Text('Conteúdo do diálogo'),
                );
              },
              child: const Text('Abrir'),
            );
          },
        ),
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Abrir'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Diálogo aberto'), findsOneWidget);
      expect(find.text('Conteúdo do diálogo'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(MedDialog),
          matching: find.byIcon(MedIcons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diálogo aberto'), findsNothing);
    });
  });

  group('MedModal', () {
    testWidgets('renders header, content and footer', (tester) async {
      await pumpTestApp(
        tester,
        const MedModal(
          title: 'Paciente',
          subtitle: 'Dados clínicos',
          leading: Icon(MedIcons.person),
          actions: <Widget>[
            Icon(MedIcons.edit),
          ],
          footer: Text('Rodapé'),
          showCloseButton: false,
          child: Text('Conteúdo principal'),
        ),
      );

      expect(find.text('Paciente'), findsOneWidget);
      expect(find.text('Dados clínicos'), findsOneWidget);
      expect(find.text('Conteúdo principal'), findsOneWidget);
      expect(find.text('Rodapé'), findsOneWidget);
      expect(find.byIcon(MedIcons.person), findsOneWidget);
      expect(find.byIcon(MedIcons.edit), findsOneWidget);
    });

    testWidgets('static show opens and closes modal', (tester) async {
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                MedModal.show<void>(
                  context: context,
                  title: 'Modal aberto',
                  child: const Text('Corpo do modal'),
                );
              },
              child: const Text('Abrir modal'),
            );
          },
        ),
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Abrir modal'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Modal aberto'), findsOneWidget);
      expect(find.text('Corpo do modal'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(MedModal),
          matching: find.byIcon(MedIcons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modal aberto'), findsNothing);
    });
  });

  group('MedBottomSheet', () {
    testWidgets('renders header, content and footer', (tester) async {
      await pumpTestApp(
        tester,
        const SizedBox(
          height: 600,
          child: MedBottomSheet(
            title: 'Filtros',
            subtitle: 'Refine os resultados',
            leading: Icon(MedIcons.search),
            actions: <Widget>[
              Icon(MedIcons.settings),
            ],
            footer: Text('Aplicar filtros'),
            showCloseButton: false,
            child: Text('Opções de filtro'),
          ),
        ),
      );

      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Refine os resultados'), findsOneWidget);
      expect(find.text('Opções de filtro'), findsOneWidget);
      expect(find.text('Aplicar filtros'), findsOneWidget);
      expect(find.byIcon(MedIcons.search), findsOneWidget);
      expect(find.byIcon(MedIcons.settings), findsOneWidget);
    });

    testWidgets('static show opens and closes sheet', (tester) async {
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                MedBottomSheet.show<void>(
                  context: context,
                  title: 'Sheet aberta',
                  child: const Text('Corpo da sheet'),
                );
              },
              child: const Text('Abrir sheet'),
            );
          },
        ),
      );

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Abrir sheet'),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Sheet aberta'), findsOneWidget);
      expect(find.text('Corpo da sheet'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(MedBottomSheet),
          matching: find.byIcon(MedIcons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sheet aberta'), findsNothing);
    });
  });
}
