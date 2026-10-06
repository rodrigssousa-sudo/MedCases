import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Reveals parsed text, never a partial Markdown source. Invisible suffix spans
/// reserve final geometry, so emphasis and line wrapping do not jump on finish.
class ClinicalMarkdownReveal extends MarkdownElementBuilder {
  ClinicalMarkdownReveal(this.progress, this.bodyStyle,
      {required this.blockOffset, required this.blockLength});
  final ValueListenable<int> progress;
  final int blockOffset, blockLength;
  int get visibleCharacters =>
      (progress.value - blockOffset).clamp(0, blockLength);
  final TextStyle bodyStyle;

  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    // flutter_markdown caches parsed children when data/style do not change.
    // Listen inside those children: replacing only the builder would leave the
    // first transparent suffix frozen, even after the reveal counter completes.
    return ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (context, value, _) => _render(
            context, element, (value - blockOffset).clamp(0, blockLength)));
  }

  Widget _render(BuildContext context, md.Element element, int visible) {
    var remaining = visible;
    final visibleText = StringBuffer();
    InlineSpan span(md.Node node, TextStyle style) {
      if (node is md.Text) {
        final chars = node.text.characters;
        final count = remaining.clamp(0, chars.length);
        final shown = chars.take(count).toString();
        remaining -= count;
        visibleText.write(shown);
        return TextSpan(children: [
          TextSpan(text: shown, style: style),
          if (count < chars.length)
            TextSpan(
                text: chars.skip(count).toString(),
                semanticsLabel: '',
                style: style.copyWith(
                    color: Colors.transparent,
                    decorationColor: Colors.transparent)),
        ]);
      }
      final e = node as md.Element;
      final next = switch (e.tag) {
        'strong' => style.copyWith(fontWeight: FontWeight.w700),
        'em' => style.copyWith(fontStyle: FontStyle.italic),
        'code' => style.copyWith(fontFamily: 'monospace'),
        _ => style,
      };
      return TextSpan(
          children: (e.children ?? []).map((n) => span(n, next)).toList());
    }

    final text = TextSpan(
        style: bodyStyle,
        children:
            (element.children ?? []).map((n) => span(n, bodyStyle)).toList());
    return Semantics(
        label: visibleText.toString(),
        child: ExcludeSemantics(
            child: SelectableText.rich(text,
                textScaler: MediaQuery.textScalerOf(context))));
  }
}

class ClinicalRevealBlock {
  ClinicalRevealBlock(this.source, this.markdown) {
    final nodes = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored)
        .parseLines(markdown.split('\n'));
    readableText = nodes.map((n) => n.textContent).join('\n');
  }
  final String source, markdown;
  late final String readableText;
  int get length => readableText.characters.length;
  bool get heading => RegExp(r'^#{1,6}\s').hasMatch(markdown);
  // Links/tables/code are parsed in full and revealed as complete semantic
  // units, preserving the existing renderer's accessibility/link behavior.
  bool get atomic =>
      heading ||
      markdown.contains('|') ||
      markdown.startsWith('```') ||
      markdown.contains('](');
}
