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

void main() {
  late String assessment;
  late String header;
  late String sectionNav;
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

  group('Avaliação V1-E — contrato visual Home V2', () {
    test('RED 01 — superfícies estruturais canônicas', () {
      for (final token in <String>[
        '0xFF1A1D23',
        '0xFF252930',
        '0xFF2D3340',
      ]) {
        expect(
          assessment,
          contains(token),
          reason: 'Token estrutural ausente: $token',
        );
      }
    });

    test('RED 02 — scaffold com tema dark e light', () {
      expect(
        assessment,
        contains('Theme.of(context).brightness'),
      );
      expect(
        assessment,
        contains('Brightness.dark'),
      );
      expect(
        assessment.contains(
          'backgroundColor: const Color(0xFFF7F8FA)',
        ),
        isFalse,
      );
    });

    test('RED 03 — cabeçalho sólido sem gradiente', () {
      expect(
        header.contains('LinearGradient('),
        isFalse,
      );
      expect(
        header.contains('0xFF1A1D23') ||
            header.contains('0xFF252930'),
        isTrue,
      );
      expect(
        header,
        contains('0xFF374151'),
      );
    });

    test('RED 04 — navegação de seções em superfície sólida', () {
      expect(
        sectionNav.contains('LinearGradient('),
        isFalse,
      );
      expect(
        sectionNav,
        contains('0xFF2D3340'),
      );
      expect(
        sectionNav,
        contains('0xFF374151'),
      );
    });

    test('RED 05 — cards de perguntas sólidos e sem sombra', () {
      expect(
        questionCard.contains('BoxShadow('),
        isFalse,
      );
      expect(
        questionCard,
        contains('0xFF252930'),
      );
      expect(
        questionCard,
        contains('0xFF2D3340'),
      );
    });

    test('RED 06 — barra inferior sólida e separada', () {
      expect(
        bottomBar.contains('LinearGradient('),
        isFalse,
      );
      expect(
        bottomBar,
        contains('0xFF252930'),
      );
      expect(
        bottomBar,
        contains('0xFF374151'),
      );
    });

    test('RED 07 — tipografia escura premium', () {
      expect(
        assessment,
        contains('0xFFF8FAFC'),
      );
      expect(
        assessment,
        contains('0xFFB2C0D0'),
      );
      expect(
        assessment,
        contains('FontWeight.w800'),
      );
    });

    test('RED 08 — separadores discretos de 0,7 px', () {
      final separatorWidths = RegExp(
        r'width\s*:\s*0\.7',
      ).allMatches(assessment).length;

      expect(
        separatorWidths,
        greaterThanOrEqualTo(2),
      );
      expect(
        assessment,
        contains('0xFF374151'),
      );
    });

    test('RED 09 — efeitos visuais pesados removidos', () {
      expect(
        assessment.contains('LinearGradient('),
        isFalse,
      );
      expect(
        assessment.contains('BoxShadow('),
        isFalse,
      );
      expect(
        assessment.contains('BackdropFilter('),
        isFalse,
      );
      expect(
        assessment.contains('ImageFilter.'),
        isFalse,
      );
    });
  });
}
