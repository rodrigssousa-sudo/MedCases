import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/action_card_button.dart';

void main() {
  testWidgets('renderiza título e ícone configurados', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionCardButton(
            title: 'Avançar Estudo',
            icon: Icons.auto_awesome_rounded,
            accentColor: const Color(0xFF1E88E5),
            dark: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Avançar Estudo'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });

  testWidgets('executa callback apenas uma vez durante debounce interno',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionCardButton(
            title: 'Calcular',
            icon: Icons.calculate_rounded,
            accentColor: const Color(0xFF10B981),
            dark: false,
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    final button = find.byType(ActionCardButton);

    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(button);
    await tester.pump();

    expect(tapCount, 1);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(button);
    await tester.pump();

    expect(tapCount, 2);

    // Consome o timer de debounce criado pelo último tap.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('renderiza corretamente no modo escuro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ActionCardButton(
            title: 'Abrir ferramenta',
            icon: Icons.calculate_rounded,
            accentColor: const Color(0xFF10B981),
            dark: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(ActionCardButton), findsOneWidget);
    expect(find.text('Abrir ferramenta'), findsOneWidget);
  });
}
