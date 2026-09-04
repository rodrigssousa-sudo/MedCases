import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/remote_clinical_response.dart';
import 'package:medcases/screens/ai/widgets/remote_clinical_action_dispatcher.dart';
import 'package:medcases/screens/ai/widgets/remote_clinical_runtime_bridge.dart';

Map<String, dynamic> _payload() => <String, dynamic>{
      'schemaVersion': 'clinical_response_v1',
      'status': 'ready',
      'language': 'es',
      'text': 'Committed final response.',
      'clinicalContext': <String, dynamic>{
        'pathologyKey': 'condition_alpha',
        'pathologyLabel': 'Condition Alpha',
        'protocolKey': 'protocol_alpha',
        'classification': <String, dynamic>{
          'key': 'severity_alpha',
          'label': 'Severity',
          'mode': 'categorical',
          'resolved': true,
          'categoryKey': 'low',
          'categoryLabel': 'Low',
          'score': null,
          'missingFacts': <String>[],
          'sourceVersion': '1',
        },
      },
      'actions': <String, dynamic>{
        'primary': <String, dynamic>{
          'actionKey': 'primary_alpha',
          'kind': 'primary',
          'actionType': 'dispatch_prompt',
          'label': 'Continuar',
          'prompt': 'Continue active context.',
          'contentRef': '',
          'payload': <String, dynamic>{},
          'sourceVersion': '1',
        },
        'classification': <String, dynamic>{
          'actionKey': 'classification_alpha',
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
      },
    };

void main() {
  test('runtime bridge rejects noncommitted reveal contract', () {
    final payload = _payload();
    final presentation = payload['presentation'] as Map<String, dynamic>;
    presentation['immutableAfterCommit'] = false;

    expect(RemoteClinicalRuntimeBridge.parse(payload), isNull);
  });

  test('runtime bridge accepts committed generic response', () {
    final response = RemoteClinicalRuntimeBridge.parse(_payload());

    expect(response, isNotNull);
    expect(response?.supportsImmutableLocalReveal, isTrue);
    expect(response?.primaryAction?.actionType, 'dispatch_prompt');
    expect(response?.classificationAction?.actionType, 'open_content_ref');
  });

  testWidgets('dispatcher sends primary prompt without clinical knowledge',
      (tester) async {
    String? dispatched;

    final dispatcher = RemoteClinicalActionDispatcher(
      onPrompt: (prompt) async {
        dispatched = prompt;
      },
      loadContentRef: (_) async => null,
    );

    final action = RemoteClinicalAction.fromJson(
      (_payload()['actions'] as Map<String, dynamic>)['primary']
          as Map<String, dynamic>,
    );

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await dispatcher.dispatch(context, action);

    expect(result, RemoteClinicalActionDispatchResult.dispatchedPrompt);
    expect(dispatched, 'Continue active context.');
  });

  testWidgets('dispatcher opens remote contentRef sheet', (tester) async {
    final dispatcher = RemoteClinicalActionDispatcher(
      onPrompt: (_) async {},
      loadContentRef: (ref) async => <String, dynamic>{
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Remote table',
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{
                'label': 'A',
                'value': 'Remote value',
              },
            ],
          },
        ],
      },
    );

    final action = RemoteClinicalAction.fromJson(
      (_payload()['actions'] as Map<String, dynamic>)['classification']
          as Map<String, dynamic>,
    );

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final future = dispatcher.dispatch(context, action);
    await tester.pumpAndSettle();

    expect(find.text('Ver clasificación'), findsOneWidget);
    expect(find.text('Remote table'), findsOneWidget);
    expect(find.text('Remote value'), findsOneWidget);

    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    expect(
      await future,
      RemoteClinicalActionDispatchResult.openedContent,
    );
  });
}
