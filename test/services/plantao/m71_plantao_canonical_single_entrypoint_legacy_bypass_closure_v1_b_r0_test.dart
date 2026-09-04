import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _codeMask(String source) {
  final out = source.codeUnits.toList();
  var i = 0;

  void blank(int index) {
    if (index >= 0 && index < out.length) out[index] = 32;
  }

  while (i < source.length) {
    if (source.startsWith('//', i)) {
      blank(i);
      blank(i + 1);
      i += 2;
      while (i < source.length && source[i] != '\n') {
        blank(i++);
      }
      continue;
    }

    if (source.startsWith('/*', i)) {
      blank(i);
      blank(i + 1);
      i += 2;
      while (i < source.length && !source.startsWith('*/', i)) {
        blank(i++);
      }
      if (i < source.length - 1) {
        blank(i);
        blank(i + 1);
        i += 2;
      }
      continue;
    }

    final rawPrefix =
        (source[i] == 'r' || source[i] == 'R') &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"') &&
        (i == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[i - 1]));

    if (rawPrefix || source[i] == "'" || source[i] == '"') {
      final raw = rawPrefix;
      final quoteIndex = raw ? i + 1 : i;
      final quote = source[quoteIndex];
      final triple = source.startsWith(quote * 3, quoteIndex);

      final prefixEnd = quoteIndex + (triple ? 3 : 1);
      for (var j = i; j < prefixEnd && j < source.length; j++) {
        blank(j);
      }
      i = prefixEnd;

      while (i < source.length) {
        if (triple && source.startsWith(quote * 3, i)) {
          blank(i);
          blank(i + 1);
          blank(i + 2);
          i += 3;
          break;
        }

        if (!triple && !raw && source[i] == r'\') {
          blank(i);
          if (i + 1 < source.length) blank(i + 1);
          i += 2;
          continue;
        }

        if (!triple && source[i] == quote) {
          blank(i++);
          break;
        }

        blank(i++);
      }
      continue;
    }

    i++;
  }

  return String.fromCharCodes(out);
}

String _balancedCall(String source, String mask, int start) {
  final open = mask.indexOf('(', start);
  expect(open, greaterThanOrEqualTo(0));

  var depth = 0;
  for (var i = open; i < mask.length; i++) {
    if (mask[i] == '(') depth++;
    if (mask[i] == ')') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }

  return '';
}

List<(int, String)> _executableSendCalls(String source) {
  final mask = _codeMask(source);
  final result = <(int, String)>[];

  for (final match in RegExp(r'\.sendAiMessage\s*\(').allMatches(mask)) {
    final call = _balancedCall(source, mask, match.start);
    expect(call, isNotEmpty);
    result.add((match.start, call));
  }

  return result;
}

String _methodBody(String source, String name) {
  final mask = _codeMask(source);
  final match = RegExp(
    'Future<bool>\\s+${RegExp.escape(name)}\\s*\\(',
  ).firstMatch(mask);
  expect(match, isNotNull, reason: 'missing $name');

  final headerOpen = mask.indexOf('(', match!.start);
  var parenDepth = 0;
  var headerClose = -1;
  for (var i = headerOpen; i < mask.length; i++) {
    if (mask[i] == '(') parenDepth++;
    if (mask[i] == ')') {
      parenDepth--;
      if (parenDepth == 0) {
        headerClose = i;
        break;
      }
    }
  }
  expect(headerClose, greaterThan(headerOpen));

  final open = mask.indexOf('{', headerClose);
  expect(open, greaterThan(headerClose));

  var depth = 0;
  for (var i = open; i < mask.length; i++) {
    if (mask[i] == '{') depth++;
    if (mask[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }

  fail('Unbalanced method: $name');
}

void main() {
  group('M71 canonical Plantao single entrypoint', () {
    final app = File('lib/providers/app_provider.dart').readAsStringSync();
    final screen = File('lib/screens/ai_screen.dart').readAsStringSync();

    test('public selector fails closed before cutover or legacy core', () {
      final selector = _methodBody(app, 'sendAiMessage');
      final guard = selector.indexOf(
        'M71_PLANTAO_CANONICAL_SINGLE_ENTRYPOINT_GUARD_V1',
      );
      final cutover = selector.indexOf('phase3kShouldAttemptBufferedCutover');
      final legacy = selector.indexOf('_sendAiMessageLegacyCore(');

      expect(app, contains('bool canonicalPlantaoWiring = false'));
      expect(guard, greaterThanOrEqualTo(0));
      expect(selector, contains('if (!canonicalPlantaoWiring)'));
      expect(
        selector,
        contains("onError('PLANTAO_CANONICAL_WIRING_REQUIRED')"),
      );
      if (cutover >= 0) expect(cutover, greaterThan(guard));
      if (legacy >= 0) expect(legacy, greaterThan(guard));
    });

    test('private core remains single-flight and terminal owner', () {
      final core = _methodBody(app, '_sendAiMessageLegacyCore');
      expect(core, contains('_aiCallInFlight'));
      expect(core, contains('AiFinalizationTransaction'));
    });

    test('only M56C primary AiScreen call authorizes Plantao', () {
      final calls = _executableSendCalls(screen);
      final canonical = calls
          .where((entry) => entry.$2.contains('canonicalPlantaoWiring: true'))
          .toList();

      expect(canonical, hasLength(1));
      expect(canonical.single.$2, contains('m56cProviderInput'));

      final auth = screen.indexOf('canonicalPlantaoWiring: true');
      final prefetch = screen.indexOf('M56C_MACHINE_NATIVE_REGISTRY_PREFETCH');
      final done = screen.indexOf('onDone: (finalText) {', auth);
      final gate = screen.indexOf(
        'PlantaoGlobalClinicalResponseGate.finalizeForPresentation(',
        done,
      );

      expect(prefetch, greaterThanOrEqualTo(0));
      expect(auth, greaterThan(prefetch));
      expect(done, greaterThan(auth));
      expect(gate, greaterThan(done));
    });

    test('all other executable direct product callers are explicit Study', () {
      final exclusions = <String>{
        'lib/providers/app_provider.dart',
        'lib/services/ai_pipeline/app_provider_ai_response_pipeline.dart',
      };

      var canonicalCount = 0;
      final violations = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final rel = entity.path.replaceFirst('${Directory.current.path}/', '');
        if (exclusions.contains(rel)) continue;

        final source = entity.readAsStringSync();

        for (final entry in _executableSendCalls(source)) {
          final call = entry.$2;
          final line =
              '\n'.allMatches(source.substring(0, entry.$1)).length + 1;

          if (call.contains('canonicalPlantaoWiring: true')) {
            canonicalCount++;
            if (!rel.endsWith('lib/screens/ai_screen.dart') ||
                !call.contains('m56cProviderInput')) {
              violations.add('$rel:$line unauthorized canonical authorization');
            }
            continue;
          }

          if (!RegExp(r'longResponse\s*:\s*true\b').hasMatch(call)) {
            violations.add(
              '$rel:$line executable direct call not explicit Study',
            );
          }
        }
      }

      expect(canonicalCount, 1);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('comment-only sendAiMessage references are ignored', () {
      const fixture =
          '// AppProvider.sendAiMessage (documentation)\n'
          '/* app_provider.sendAiMessage() */\n'
          'void f() {\n'
          '  final label = ".sendAiMessage(fake)";\n'
          '}\n';

      expect(_executableSendCalls(fixture), isEmpty);
    });

    test('M70C and M58 safety owners remain present', () {
      final gate = File(
        'lib/services/plantao_global_clinical_response_gate.dart',
      ).readAsStringSync();
      final ai = File('lib/services/ai_service.dart').readAsStringSync();

      expect(
        gate,
        contains(
          'M70C_PRE_DEDUP_MACHINE_VALIDATION_POST_DEDUP_PRESENTATION_V1',
        ),
      );
      expect(ai, contains('M58_MACHINE_NATIVE_SYSTEM_PROMPT_V1'));
    });
  });
}
