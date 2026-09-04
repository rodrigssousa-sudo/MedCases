import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String blockBetween(
  String source,
  String startMarker, [
  String? endMarker,
]) {
  final start = source.indexOf(startMarker);
  if (start < 0) {
    throw StateError('Marcador inicial ausente: $startMarker');
  }

  if (endMarker == null) {
    return source.substring(start);
  }

  final end = source.indexOf(
    endMarker,
    start + startMarker.length,
  );
  if (end < 0) {
    throw StateError('Marcador final ausente: $endMarker');
  }

  return source.substring(start, end);
}

int countMatches(String source, RegExp pattern) {
  return pattern.allMatches(source).length;
}

void main() {
  late String assessment;
  late String header;
  late String sectionNav;
  late String sectionContent;
  late String questionCard;
  late String bottomBar;

  setUpAll(() {
    assessment = File(
      'lib/screens/avaliacao_screen.dart',
    ).readAsStringSync();

    header = blockBetween(
      assessment,
      'class _AvalHeader',
      'class _SectionNav',
    );
    sectionNav = blockBetween(
      assessment,
      'class _SectionNav',
      'class _SectionContent',
    );
    sectionContent = blockBetween(
      assessment,
      'class _SectionContent',
      'class _QuestionCard',
    );
    questionCard = blockBetween(
      assessment,
      'class _QuestionCard',
      'class _BottomBar',
    );
    bottomBar = blockBetween(
      assessment,
      'class _BottomBar',
    );
  });

  group('Avaliação V1-H — contrato de descardificação', () {
    test('RED 01 — voltar é ação simples sem card decorativo', () {
      expect(
        header,
        contains('IconButton('),
      );
      expect(
        header.contains('Material('),
        isFalse,
      );
      expect(
        header.contains('InkWell('),
        isFalse,
      );
      expect(
        countMatches(
          header,
          RegExp(r'BorderRadius\.circular'),
        ),
        0,
      );
    });

    test('RED 02 — navegação usa sublinhado e não cápsulas', () {
      expect(
        sectionNav.contains('Border.all('),
        isFalse,
      );
      expect(
        sectionNav.contains('BorderRadius.circular(12)'),
        isFalse,
      );
      expect(
        sectionNav,
        contains('Alignment.bottomCenter'),
      );
      expect(
        sectionNav,
        contains('height: 2'),
      );
    });

    test('RED 03 — título da seção não envolve ícone em card', () {
      expect(
        sectionContent.contains('iconSurface'),
        isFalse,
      );
      expect(
        sectionContent.contains('width: 38'),
        isFalse,
      );
      expect(
        sectionContent.contains('height: 38'),
        isFalse,
      );
    });

    test('RED 04 — cada seção possui uma única superfície clínica', () {
      expect(
        assessment,
        contains('class _SectionSurface'),
      );
      expect(
        countMatches(
          sectionContent,
          RegExp(r'\b_SectionSurface\s*\('),
        ),
        1,
      );
      expect(
        assessment,
        contains('Divider('),
      );
    });

    test('RED 05 — pergunta é grupo com divisor e não card', () {
      expect(
        RegExp(
          r'return\s+Container\s*\(',
        ).hasMatch(questionCard),
        isFalse,
      );
      expect(
        RegExp(
          r'return\s+Padding\s*\(',
        ).hasMatch(questionCard),
        isTrue,
      );
      expect(
        questionCard.contains(
          'margin: const EdgeInsets.only(bottom: 10)',
        ),
        isFalse,
      );
    });

    test('RED 06 — opções inativas são leves e transparentes', () {
      expect(
        questionCard,
        contains('Colors.transparent'),
      );
      expect(
        RegExp(
          r'color\s*:\s*selected\s*\?\s*'
          r'sectionColor\s*:\s*surfaceStrong',
        ).hasMatch(questionCard),
        isFalse,
      );
    });

    test('RED 07 — rodapé usa ações secundárias sem cards e CTA estável', () {
      expect(
        countMatches(
          bottomBar,
          RegExp(r'\bTextButton\.icon\s*\('),
        ),
        greaterThanOrEqualTo(3),
      );
      expect(
        countMatches(
          bottomBar,
          RegExp(r'\bFilledButton\.icon\s*\('),
        ),
        greaterThanOrEqualTo(1),
      );
      expect(
        bottomBar.contains('? section.color'),
        isFalse,
      );
      expect(
        bottomBar,
        contains('backgroundColor: _kGreen'),
      );
    });

    test('RED 08 — orçamento de decoração elimina bordas aninhadas', () {
      final inspected = sectionContent + questionCard;

      expect(
        countMatches(
          inspected,
          RegExp(r'decoration\s*:\s*BoxDecoration\s*\('),
        ),
        lessThanOrEqualTo(2),
      );
      expect(
        countMatches(
          inspected,
          RegExp(r'\bBorder\.all\s*\('),
        ),
        lessThanOrEqualTo(2),
      );
    });
  });
}
