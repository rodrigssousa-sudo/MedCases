import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Presentation only. The original text remains the source for copy/history.
class PlantaoEditorialStyle {
  static const readingMaxWidth = 720.0;
  static double gutter(double width) => width >= 600 ? 32 : 24;

  static MarkdownStyleSheet markdown(BuildContext context, bool dark) {
    final color = dark ? const Color(0xffeceff2) : const Color(0xff202830);
    final body = TextStyle(fontSize: 15, height: 1.48, color: color);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      listBullet: body.copyWith(fontSize: 13),
      strong: body.copyWith(fontWeight: FontWeight.w700),
      h1: body.copyWith(
          fontSize: 23, height: 1.22, fontWeight: FontWeight.w700),
      h2: body.copyWith(
          fontSize: 18, height: 1.28, fontWeight: FontWeight.w600),
      h3: body.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600),
      blockSpacing: 10,
      listIndent: 16,
      listBulletPadding: const EdgeInsets.only(right: 7),
      tableHead: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      tableBody: body.copyWith(fontSize: 14),
      tableCellsPadding: const EdgeInsets.all(10),
      tableBorder: TableBorder.all(
          color: dark ? const Color(0xff414b55) : const Color(0xffcbd1d8)),
      tableColumnWidth: const FlexColumnWidth(),
      a: body.copyWith(decoration: TextDecoration.underline),
    );
  }

  static EdgeInsets spacing(String block, {required bool first}) {
    if (block.startsWith('# ')) {
      return EdgeInsets.only(top: first ? 0 : 18, bottom: 14);
    }
    if (block.startsWith('## ')) {
      return EdgeInsets.only(top: first ? 0 : 16, bottom: 14);
    }
    if (block.startsWith('### ')) {
      return const EdgeInsets.only(top: 10, bottom: 10);
    }
    return EdgeInsets.only(bottom: block.startsWith('- ') ? 8 : 12);
  }

  static bool isReferenceHeading(String text) => RegExp(
          r'^#{1,3}\s+(?:refer[eê]ncias?|referencias?|references|bibliograf[ií]a)\s*:?$',
          caseSensitive: false)
      .hasMatch(text.trim());

  /// Hold an unfinished inline construct, so bold/link styling never flashes
  /// from raw Markdown into final styling after its closing delimiter arrives.
  static String completeMarkdownPrefix(String text, {bool includeSafeSentenceTail = false}) {
    final lines = text.split('\n');
    var offset = 0;
    var accepted = 0;
    var fenced = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = offset + line.length;
      if (line.trimLeft().startsWith('```')) fenced = !fenced;
      final balanced = '**'.allMatches(line).length.isEven &&
          '`'.allMatches(line).length.isEven &&
          '['.allMatches(line).length == ']'.allMatches(line).length &&
          '('.allMatches(line).length == ')'.allMatches(line).length;
      if (!fenced && (balanced || line.trimLeft().startsWith('```'))) {
        if (i < lines.length - 1) {
          // A real line boundary closes the whole block. A sentence inside
          // a still-growing paragraph does not: freezing it would split/rejoin
          // that same block when the completed snapshot arrives.
          accepted = end + 1;
        } else if (includeSafeSentenceTail &&
            !line.trimLeft().startsWith('#') &&
            !line.contains('|') &&
            !line.trimLeft().startsWith('```') &&
            RegExp(r'[.!?]$').hasMatch(line.trimRight())) {
          // This is a safety-validated snapshot, not raw provider tokens.
          // Keep the growing paragraph mutable until its real newline arrives.
          accepted = end;
        }
      } else if (!fenced && !line.trimLeft().startsWith('```')) {
        break;
      }
      offset = end + 1;
    }
    return text.substring(0, accepted);
  }

  static const _acronyms = {
    'IAM',
    'SCA',
    'ACS',
    'ECG',
    'TEP',
    'TVP',
    'UCI',
    'UTI',
    'IV',
    'VO',
    'IM',
    'SC',
    'IR',
    'XR',
    'TFG',
    'AAS',
    'DM2',
    'HIV',
    'VIH',
    'EPOC',
    'DPOC',
    'B12',
    'PCR',
    'INR',
    'SNC',
    'IRA',
  };

  static String formatBlock(String block, String lang) {
    if (block.startsWith('```')) return block;
    if (lang.startsWith('pt') || lang.startsWith('es')) {
      // Localize only the interval prefix; keep every quantity/unit intact.
      block = block.splitMapJoin(
        RegExp(r'`[^`]*`|\[[^\]]*\]\([^)]*\)|https?://\S+'),
        onMatch: (m) => m[0]!,
        onNonMatch: (text) => text.replaceAll(
          RegExp(
              r'\bq[ \t]*(?=\d+(?:[.,]\d+)?(?:[ \t]*[–—-][ \t]*\d+(?:[.,]\d+)?)?[ \t]*(?:h|min)\b)',
              caseSensitive: false),
          'c/',
        ),
      );
    }
    final heading = RegExp(r'^(#{1,6}\s+)(.+)$').firstMatch(block);
    if (heading != null) {
      var title = heading[2]!;
      if (RegExp(r'^red flags\s*:?$', caseSensitive: false).hasMatch(title)) {
        title = lang.startsWith('es') ? 'Signos de alarma' : 'Sinais de alarme';
      } else if (!title.contains('*')) {
        final words = title.split(' ');
        title = List.generate(words.length, (i) {
          final word = words[i];
          if (_acronyms.contains(word)) return word;
          if (i == 0 && word.isNotEmpty) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }
          return word.toLowerCase();
        }).join(' ');
      }
      return '${heading[1]}$title';
    }
    // Existing emphasis, code, links and URLs are opaque: never nest Markdown
    // markers in them or change a medical number/route/unit.
    final opaque =
        RegExp(r'\*\*[^*]+\*\*|`[^`]*`|\[[^\]]*\]\([^)]*\)|https?://\S+');
    final result = StringBuffer();
    var offset = 0;
    for (final match in opaque.allMatches(block)) {
      result.write(_emphasize(block.substring(offset, match.start)));
      result.write(match[0]);
      offset = match.end;
    }
    result.write(_emphasize(block.substring(offset)));
    return result.toString();
  }

  static final _dose = RegExp(
      r'\b\d+(?:[.,]\d+)?(?:\s*[–—-]\s*\d+(?:[.,]\d+)?)?\s*'
      r'(?:mcg|µg|μg|mg|g|mL|ml|UI|IU|U)(?:/(?:kg|min|h|d[ií]a|dia))*(?![a-zA-Z])'
      r'(?:\s+(?:VO|IV|IM|SC|EV))?|\b(?:VO|IV|IM|SC|EV)\b|'
      r'\b(?:cada|a cada)\s+\d+(?:\s*[–-]\s*\d+)?\s*(?:horas?|h|minutos?|min)\b');

  static String _emphasize(String text) =>
      text.replaceAllMapped(_dose, (m) => '**${m[0]}**');
}

/// Wraps the whole answer, including its actions/references, in one column.
class PlantaoReadingColumn extends StatelessWidget {
  const PlantaoReadingColumn(
      {super.key, required this.child, this.parentInset = 0});
  final Widget child;
  final double parentInset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: (PlantaoEditorialStyle.gutter(
                        MediaQuery.sizeOf(context).width) -
                    parentInset)
                .clamp(0, 32)),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: PlantaoEditorialStyle.readingMaxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      );
}
