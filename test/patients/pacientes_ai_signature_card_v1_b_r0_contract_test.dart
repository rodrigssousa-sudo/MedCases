import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String methodBlock(
  String source,
  String anchor,
  String nextAnchor,
) {
  final start = source.indexOf(anchor);
  expect(start, greaterThanOrEqualTo(0), reason: anchor);

  final end = source.indexOf(nextAnchor, start);
  expect(end, greaterThan(start), reason: nextAnchor);

  return source.substring(start, end);
}

void main() {
  final copilot =
      read('lib/screens/internacion/components/copilot_button.dart');

  group('Pacientes IA signature card', () {
    test('uses official MedCases IA identity asset', () {
      expect(
        copilot,
        contains("package:flutter_svg/flutter_svg.dart"),
      );
      expect(
        copilot,
        contains("assets/icons/home_v2/ic_ia.svg"),
      );
      expect(
        copilot,
        contains('MEDCASES_PACIENTES_AI_SIGNATURE_CARD_V1_B_R0'),
      );
    });

    test('communicates clinical AI hierarchy and action', () {
      expect(copilot, contains("'IA CLÍNICA'"));
      expect(copilot, contains("'MedCases Inteligente'"));
      expect(copilot, contains("'Abrir'"));
      expect(
        copilot,
        contains("'Texto o imagen → organiza el SOAP'"),
      );
      expect(
        copilot,
        contains("'Texto ou imagem → organiza o SOAP'"),
      );
    });

    test('signature surface stays premium without heavy effects', () {
      final build = methodBlock(
        copilot,
        'Widget build(BuildContext context) {',
        'Widget _buildIdleState()',
      );

      expect(build, contains('Color(0xFF202A29)'));
      expect(build, contains('Color(0xFFF4FAF7)'));
      expect(build, contains('BorderRadius.circular(10)'));
      expect(build, contains('width: 0.8'));
      expect(build, isNot(contains('LinearGradient(')));
      expect(build, isNot(contains('BoxShadow(')));
    });

    test('official icon receives subtle micro motion only', () {
      final idle = methodBlock(
        copilot,
        'Widget _buildIdleState() {',
        'Widget _buildLoadingState()',
      );

      final iconStart = idle.indexOf('AnimatedBuilder(');
      expect(iconStart, greaterThanOrEqualTo(0));

      final iconEnd = idle.indexOf(
        'const SizedBox(width: 12)',
        iconStart,
      );
      expect(iconEnd, greaterThan(iconStart));

      final iconBlock = idle.substring(iconStart, iconEnd);

      expect(copilot, contains('animation: _shimmerCtrl'));
      expect(
        copilot,
        contains(
          'final lift = 1.5 * (1 - ((2 * t) - 1).abs());',
        ),
      );
      expect(
        copilot,
        contains('offset: Offset(0, -lift)'),
      );
      expect(iconBlock, contains('child: SizedBox('));
      expect(iconBlock, contains('width: 38'));
      expect(iconBlock, contains('height: 38'));
      expect(
        iconBlock,
        contains("assets/icons/home_v2/ic_ia.svg"),
      );
      expect(
        iconBlock,
        isNot(contains('padding: const EdgeInsets.all(8)')),
      );
      expect(iconBlock, isNot(contains('BoxDecoration(')));
      expect(
        iconBlock,
        isNot(
          contains(
            'InternacionTheme.accentLight.withOpacity(',
          ),
        ),
      );
    });

    test('loading state keeps same IA identity', () {
      expect(
        copilot,
        contains("isEs ? 'Organizando SOAP…' : 'Organizando SOAP…'"),
      );
      expect(copilot, contains('CircularProgressIndicator('));
      expect(copilot, contains('width: 38'));
      expect(copilot, contains('height: 38'));
      expect(
        RegExp(
          r"assets/icons/home_v2/ic_ia\.svg",
        ).allMatches(copilot).length,
        2,
      );
    });

    test('processing pipeline remains wired', () {
      for (final token in [
        '_openInputSheet',
        '_handleSubmit',
        'SoapCopilotService.extractSoap(',
        'RevisionSheet.show(',
        'widget.onApproved(draft)',
      ]) {
        expect(copilot, contains(token), reason: token);
      }
    });
  });
}
