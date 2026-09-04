import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/remote_clinical_response.dart';
import 'package:medcases/screens/ai/widgets/remote_clinical_response_renderer.dart';

void main() {
  Map<String, dynamic> readyPayload() => <String, dynamic>{
        'schemaVersion': 'clinical_response_v1',
        'status': 'ready',
        'language': 'es',
        'text': 'Respuesta clínica final validada.',
        'clinicalContext': <String, dynamic>{
          'pathologyKey': 'condition_alpha',
          'pathologyLabel': 'Condition Alpha',
          'protocolKey': 'protocol_current',
          'classification': <String, dynamic>{
            'key': 'severity_alpha',
            'label': 'Severity',
            'mode': 'categorical',
            'resolved': true,
            'categoryKey': 'low',
            'categoryLabel': 'Low',
            'score': null,
            'missingFacts': <String>[],
            'sourceVersion': '2',
          },
        },
        'actions': <String, dynamic>{
          'primary': <String, dynamic>{
            'actionKey': 'primary_specific',
            'kind': 'primary',
            'actionType': 'dispatch_prompt',
            'label': 'Continuar manejo',
            'prompt': 'Continuar el manejo específico.',
            'contentRef': '',
            'payload': <String, dynamic>{},
            'sourceVersion': '1',
          },
          'classification': <String, dynamic>{
            'actionKey': 'classification_specific',
            'kind': 'classification',
            'actionType': 'open_content_ref',
            'label': 'Ver clasificación',
            'prompt': '',
            'contentRef': 'classification_alpha_table',
            'payload': <String, dynamic>{},
            'sourceVersion': '1',
          },
        },
        'presentation': <String, dynamic>{
          'revealMode': 'local_progressive_after_commit',
          'immutableAfterCommit': true,
          'allowVisibleTextMutation': false,
          'actionsStableWithResponse': true,
        },
      };

  test('parses generic structured response without pathology logic', () {
    final response = RemoteClinicalResponse.fromJson(readyPayload());

    expect(response.isReady, isTrue);
    expect(response.supportsImmutableLocalReveal, isTrue);
    expect(response.primaryAction?.label, 'Continuar manejo');
    expect(response.classificationAction?.contentRef,
        'classification_alpha_table');
  });

  testWidgets('renders both generic remote actions', (tester) async {
    final response = RemoteClinicalResponse.fromJson(readyPayload());
    final tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteClinicalResponseRenderer(
            response: response,
            onAction: (action) => tapped.add(action.actionKey),
            textBuilder: (_, text) => Text(text),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Continuar manejo'), findsOneWidget);
    expect(find.text('Ver clasificación'), findsOneWidget);

    await tester.tap(find.text('Continuar manejo'));
    await tester.pump();
    expect(tapped, contains('primary_specific'));

    await tester.tap(find.text('Ver clasificación'));
    await tester.pump();
    expect(tapped, contains('classification_specific'));
  });

  testWidgets('waiting state renders missing facts without invented category',
      (tester) async {
    final payload = readyPayload();
    payload['status'] = 'waiting_for_facts';
    payload['text'] = '';
    final context = payload['clinicalContext'] as Map<String, dynamic>;
    final classification = context['classification'] as Map<String, dynamic>;
    classification['resolved'] = false;
    classification['categoryKey'] = '';
    classification['categoryLabel'] = '';
    classification['missingFacts'] = <String>['marker.value'];

    final response = RemoteClinicalResponse.fromJson(payload);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteClinicalResponseRenderer(
            response: response,
            onAction: (_) {},
            textBuilder: (_, text) => Text(text),
          ),
        ),
      ),
    );

    expect(find.textContaining('marker.value'), findsOneWidget);
    expect(response.classification.categoryKey, isEmpty);
  });
}
