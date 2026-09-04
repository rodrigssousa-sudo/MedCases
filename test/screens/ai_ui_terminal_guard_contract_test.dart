import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PHASE3I-J2B1 V4 terminal guard contract', () {
    late String screen;
    late String provider;

    setUpAll(() {
      screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      provider = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    test('terminal callbacks release the synchronous send guard', () {
      expect(
        screen,
        contains('PHASE3I-J2B1: terminal ownership reached'),
      );

      final releaseCount =
          RegExp(r'_sendGuard\s*=\s*false;').allMatches(screen).length;
      expect(releaseCount, greaterThanOrEqualTo(4));

      expect(
        RegExp(
          r'onError:\s*\(errorMsg\)\s*\{[\s\S]{0,220}'
          r'_sendGuard\s*=\s*false;',
        ).hasMatch(screen),
        isTrue,
      );

      expect(
        RegExp(
          r'onStructuredDone:\s*\(finalText,\s*clinicalOutput\)\s*\{'
          r'[\s\S]{0,220}_sendGuard\s*=\s*false;',
        ).hasMatch(screen),
        isTrue,
      );
    });

    test('outer exception path releases the send guard', () {
      expect(
        RegExp(
          r'Captura exceções não tratadas[\s\S]{0,260}'
          r'_sendGuard\s*=\s*false;',
        ).hasMatch(screen),
        isTrue,
      );
    });

    test('raw auth-expired markers are absent from provider UI messages', () {
      expect(provider, isNot(contains('[auth_expired]')));
      expect(
        provider,
        contains(
          'Não foi possível reconectar. Verifique sua conexão e tente novamente.',
        ),
      );
      expect(
        provider,
        contains(
          'No fue posible reconectar. Verifica tu conexión e inténtalo nuevamente.',
        ),
      );
    });
  });
}
