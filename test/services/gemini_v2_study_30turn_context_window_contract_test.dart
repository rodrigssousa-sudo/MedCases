import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodBlock(String source, String methodName) {
  final start = source.indexOf(methodName);
  if (start < 0) {
    throw StateError('method missing: $methodName');
  }
  final open = source.indexOf('{', start);
  if (open < 0) {
    throw StateError('open brace missing: $methodName');
  }

  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = open; i < source.length; i++) {
    final c = source[i];
    final n = i + 1 < source.length ? source[i + 1] : '';

    if (inLineComment) {
      if (c == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (c == '*' && n == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inSingle) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == "'") {
        inSingle = false;
      }
      continue;
    }
    if (inDouble) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inDouble = false;
      }
      continue;
    }

    if (c == '/' && n == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (c == '/' && n == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (c == "'") {
      inSingle = true;
      continue;
    }
    if (c == '"') {
      inDouble = true;
      continue;
    }
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open, i + 1);
      }
    }
  }
  throw StateError('unbalanced method: $methodName');
}

void main() {
  test('Gemini V2 downstream context window allows 30 exchange pairs', () {
    final source =
        File('lib/services/gemini_service_v2.dart').readAsStringSync();
    final block = _methodBlock(
      source,
      'static List<Map<String, String>> _buildContextWindow(',
    );

    expect(block, contains("contextLabel == 'NOVO'"));
    expect(block, contains('return [];'));
    expect(block, contains('const maxPairs = 30;'));
    expect(block, contains('const maxEntries = maxPairs * 2;'));
    expect(block, isNot(contains('const maxPairs = 2;')));
  });
}
