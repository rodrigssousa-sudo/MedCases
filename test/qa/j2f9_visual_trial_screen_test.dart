import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/qa/j2f9_visual_trial_screen.dart';

void main() {
  group('PHASE3I-J2F9B isolated visual trial', () {
    testWidgets('starts in PT light legacy mode', (tester) async {
      await tester.pumpWidget(const J2F9VisualTrialApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('j2f9_visual_trial_root')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('j2f9_legacy_pt_light')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('guardia_pharmacologic_section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('typed_treatment_shadow_root')),
        findsNothing,
      );
    });

    testWidgets('switches explicitly to PT typed', (tester) async {
      await tester.pumpWidget(const J2F9VisualTrialApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('j2f9_renderer_typed')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('j2f9_typed_pt_light')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('typed_treatment_shadow_root')),
        findsOneWidget,
      );
      expect(find.text('Tratamento concomitante:'), findsOneWidget);
    });

    testWidgets('supports ES dark typed without mixed heading', (tester) async {
      await tester.pumpWidget(const J2F9VisualTrialApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('j2f9_language_es')));
      await tester.tap(find.byKey(const ValueKey('j2f9_theme_dark')));
      await tester.tap(find.byKey(const ValueKey('j2f9_renderer_typed')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('j2f9_typed_es_dark')),
        findsOneWidget,
      );
      expect(find.text('Tratamiento concomitante:'), findsOneWidget);
      expect(find.text('Tratamento concomitante:'), findsNothing);
    });

    testWidgets('all controls remain usable at 320 px width', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const J2F9VisualTrialApp());
      await tester.pumpAndSettle();

      for (final key in <String>[
        'j2f9_language_pt',
        'j2f9_language_es',
        'j2f9_theme_light',
        'j2f9_theme_dark',
        'j2f9_renderer_legacy',
        'j2f9_renderer_typed',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });

    test('alternate entrypoint remains disconnected from productive main', () {
      final main = File('lib/main.dart').readAsStringSync();
      final provider =
          File('lib/providers/app_provider.dart').readAsStringSync();
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
      final entrypoint =
          File('lib/main_j2f9_visual_trial.dart').readAsStringSync();

      expect(
        entrypoint,
        contains(
          'PHASE3I-J2F9B: isolated device visual trial entrypoint',
        ),
      );
      expect(main, isNot(contains('J2F9VisualTrialApp')));
      expect(provider, isNot(contains('J2F9VisualTrialApp')));
      expect(renderer, isNot(contains('J2F9VisualTrialApp')));
    });

    test('isolated entrypoint has no Firebase, auth or provider boot', () {
      final entrypoint =
          File('lib/main_j2f9_visual_trial.dart').readAsStringSync();
      final screen =
          File('lib/qa/j2f9_visual_trial_screen.dart').readAsStringSync();
      final combined = '$entrypoint\n$screen';

      final forbidden = <String>[
        'Firebase' 'Firestore',
        'Firebase' 'Auth',
        'Firebase.initializeApp',
        'App' 'Provider(',
        'Firestore' 'Service',
        'Shared' 'Preferences',
      ];

      for (final token in forbidden) {
        expect(combined, isNot(contains(token)));
      }
    });
  });
}
