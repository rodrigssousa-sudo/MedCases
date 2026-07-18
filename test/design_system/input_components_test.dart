import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: MedTheme.light,
      darkTheme: MedTheme.dark,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(MedSpacing.lg),
          child: child,
        ),
      ),
    );
  }

  group('MedInput', () {
    testWidgets('renders labels, hint and helper text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedInput(
            label: 'Paciente',
            hint: 'Digite o nome',
            helperText: 'Nome completo',
          ),
        ),
      );

      expect(find.text('Paciente'), findsOneWidget);
      expect(find.text('Digite o nome'), findsOneWidget);
      expect(find.text('Nome completo'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('propagates text changes', (tester) async {
      String? value;

      await tester.pumpWidget(
        buildTestApp(
          MedInput(
            label: 'Paciente',
            onChanged: (text) => value = text,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Maria');
      await tester.pump();

      expect(value, 'Maria');
    });

    testWidgets('supports every official state', (tester) async {
      for (final state in MedInputState.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedInput(
              key: ValueKey<MedInputState>(state),
              label: state.name,
              state: state,
              errorText: state == MedInputState.error ? 'Erro' : null,
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
      }
    });

    testWidgets('invokes suffix callback', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedInput(
            label: 'Senha',
            suffixIcon: MedIcons.information,
            onSuffixPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.byIcon(MedIcons.information));
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('does not allow changes when disabled', (tester) async {
      String? value;

      await tester.pumpWidget(
        buildTestApp(
          MedInput(
            label: 'Bloqueado',
            enabled: false,
            onChanged: (text) => value = text,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Teste');
      await tester.pump();

      expect(value, isNull);
    });
  });

  group('MedTextField', () {
    testWidgets('delegates rendering to MedInput', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedTextField(
            label: 'Observação',
            hint: 'Digite uma observação',
          ),
        ),
      );

      expect(find.byType(MedTextField), findsOneWidget);
      expect(find.byType(MedInput), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('supports multiline content', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedTextField(
            label: 'Evolução',
            minLines: 3,
            maxLines: 6,
          ),
        ),
      );

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );

      expect(editableText.minLines, 3);
      expect(editableText.maxLines, 6);
    });

    testWidgets('supports password configuration', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedTextField(
            label: 'Senha',
            obscureText: true,
          ),
        ),
      );

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );

      expect(editableText.obscureText, isTrue);
      expect(editableText.maxLines, 1);
    });
  });

  group('MedSearchBar', () {
    testWidgets('propagates search changes and submission', (tester) async {
      String? changed;
      String? submitted;

      await tester.pumpWidget(
        buildTestApp(
          MedSearchBar(
            onChanged: (value) => changed = value,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'dipirona');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(changed, 'dipirona');
      expect(submitted, 'dipirona');
    });

    testWidgets('shows and executes clear action', (tester) async {
      var clears = 0;
      final controller = TextEditingController(text: 'paracetamol');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          MedSearchBar(
            controller: controller,
            onClear: () => clears += 1,
          ),
        ),
      );

      expect(find.byIcon(MedIcons.close), findsOneWidget);

      await tester.tap(find.byIcon(MedIcons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(clears, 1);
      expect(find.byIcon(MedIcons.close), findsNothing);
    });

    testWidgets('hides clear action when configured', (tester) async {
      final controller = TextEditingController(text: 'teste');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          MedSearchBar(
            controller: controller,
            showClearButton: false,
          ),
        ),
      );

      expect(find.byIcon(MedIcons.close), findsNothing);
    });

    testWidgets('uses an internal controller safely', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedSearchBar(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'interno');
      await tester.pump();

      expect(find.text('interno'), findsOneWidget);
      expect(find.byIcon(MedIcons.close), findsOneWidget);
    });
  });
}
