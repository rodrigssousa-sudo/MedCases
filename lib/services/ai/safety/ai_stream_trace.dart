import 'dart:convert';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'ai_trace_sink_stub.dart' if (dart.library.io) 'ai_trace_sink_io.dart';
/// Counts and fixed codes only. Never prompts, answers, UID, tokens or errors.
class AiStreamTrace {
  static final _clock = Stopwatch()..start();
  static int _index = 0;
  static const fingerprint = String.fromEnvironment('AI_TRACE_BUILD', defaultValue: 'UNSTAMPED');

  // Diagnostic-only boundaries. No content, identifiers or dynamic reason text.
  static void stage(String stage, String input, String output) {
    content('${stage}_IN', input);
    content('${stage}_OUT', output);
    markers('${stage}_IN', input);
    markers('${stage}_OUT', output);
  }
  static void markers(String stage, String text) {
    final patterns = <String, String>{
      'TREATMENT': r'tratam|tratamiento|terap',
      'LACTULOSE': r'lactulos',
      'RIFAXIMIN': r'rifaximin',
      'STANDARD_DOSE': r'(dose|dosis).{0,40}(refer[eê]ncia|referencia|padr[aã]o|est[aá]ndar)',
      'NUMERIC_DOSE': r'\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|g|ml|mL|UI)\b',
      'MONITORING': r'monitor|reavali|reevalu|vigilancia|seguimiento',
      'REFERENCES': r'refer[eê]ncia|referencia|bibliograf|https?://',
    };
    for (final entry in patterns.entries) {
      mark('${stage}_HAS_${entry.key}', RegExp(entry.value, caseSensitive: false).hasMatch(text) ? 1 : 0);
    }
  }
  static void content(String stage, String text) {
    if (kReleaseMode || !RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(stage)) return;
    final digest = const DartSha256().hashSync(utf8.encode(text)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    writeAiTrace('[AI_STREAM] stage=${stage}_CONTENT t=${_clock.elapsedMilliseconds} '
        'index=${++_index} count=${text.length} hash=$digest');
  }
  static void mark(String stage, int chars) {
    if (kReleaseMode || !RegExp(r'^[A-Z0-9_]{1,80}$').hasMatch(stage)) return;
    final stamp = RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ? fingerprint : 'UNSTAMPED';
    final line='[AI_STREAM] stage=$stage t=${_clock.elapsedMilliseconds} index=${++_index} count=$chars build=$stamp';
    writeAiTrace(line);
  }
}
