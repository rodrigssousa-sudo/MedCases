import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plantao final identity cleanup is display-only', () {
    final ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    final guardia = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();

    expect(ai, contains('final hasAutomaticVisibleProjection ='));
    expect(ai, contains('displayCandidate.isNotEmpty ||'));
    expect(ai, contains('policyVisibleText.trim() != msg.text.trim()'));
    expect(
      ai,
      contains('if (!_longResponse && !hasAutomaticVisibleProjection)'),
    );
    expect(
      ai,
      contains("'msg_\${msg.id}_plantao_direct_user_hidden'"),
    );

    expect(ai, contains('editText: msg.text'));
    expect(ai, contains('onCopy: () => _copyMsg(userVisibleText)'));
    expect(ai, contains('msg.userDisplayText?.trim()'));
    expect(
      RegExp(
        r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
        multiLine: true,
      ).hasMatch(ai),
      isTrue,
    );

    expect(guardia, contains('(?:conducta|conduta)'));
    expect(guardia, contains('(?:inmediata|imediata)'));
    expect(guardia, contains(r'manejo\s+(?:inmediato|imediato)'));

    expect(
      guardia,
      contains('final hasUserCertaintyContext = userNorm.isNotEmpty;'),
    );
    expect(guardia, contains("'Orientación clínica'"));
    expect(guardia, contains("'Posibilidades clínicas prioritarias'"));
  });
}
