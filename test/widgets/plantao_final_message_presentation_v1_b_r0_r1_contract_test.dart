import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plantao final message presentation remains display-only', () {
    final ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    final user = File('lib/screens/ai/widgets/user_bubble.dart').readAsStringSync();
    final guardia = File('lib/screens/ai/widgets/guardia_clinical_response_view.dart').readAsStringSync();

    expect(user, contains('final bool cleanPlantaoPresentation;'));
    expect(user, contains('if (!widget.cleanPlantaoPresentation) ...['));
    expect(ai, contains('cleanPlantaoPresentation: !_longResponse'));
    expect(ai, contains('if (_longResponse || isActiveStreamingBubble) ...['));
    expect(ai, contains('editText: msg.text'));
    expect(ai, contains('onCopy: () => _copyMsg(userVisibleText)'));
    expect(ai, contains('userDisplayText: visibleLabel'));
    expect(ai, contains('userText: precedingUserText'));
    expect(ai, contains('userInitiatedByAction: precedingUserWasAction'));

    expect(guardia, contains('class _GuardiaTitleProjection'));
    expect(guardia, contains("'Orientación clínica'"));
    expect(guardia, isNot(contains("'Hipótesis principal'")));
    expect(
      guardia,
      contains("'Posibilidades clínicas prioritarias'"),
    );
    expect(guardia, contains("'Red flags/escalamiento'"));
    expect(guardia, contains("'Red flags/escalonamento'"));
    expect(guardia, contains('_normalizeGuardiaNoteLabel(text)'));

    final a = guardia.indexOf('class _DiagnosisHeader');
    final b = guardia.indexOf('class _SectionTitle');
    expect(a, greaterThanOrEqualTo(0));
    expect(b, greaterThan(a));
    final widget = guardia.substring(a, b);
    expect(widget, isNot(contains("'🔴'")));
    expect(widget, isNot(contains('toUpperCase()')));
    expect(widget, contains('fontSize: 17.0'));
  });
}
