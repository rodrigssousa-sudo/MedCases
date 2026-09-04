import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/ai/widgets/study_continuation_button.dart';

void main() {
  testWidgets('exibe somente label curto e bloqueia toque duplo imediato',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyContinuationButton(
            label: 'Manejo inicial',
            dark: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Manejo inicial'), findsOneWidget);
    expect(find.text('¿Cómo se realiza el manejo inicial de la LRA?'),
        findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.tap(find.byType(InkWell), warnIfMissed: false);
    await tester.pump();
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 650));
  });

  testWidgets('remove emoji residual do label visível', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyContinuationButton(
            label: '📌 Critérios de gravidade',
            dark: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Critérios de gravidade'), findsOneWidget);
    expect(find.text('📌 Critérios de gravidade'), findsNothing);
  });

  testWidgets('cancela timer quando removido da árvore', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyContinuationButton(
            label: 'Próximo ponto',
            dark: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
  });
}
